# frozen_string_literal: true

require "optparse"
require_relative "../rails_agent_harness"
require_relative "installer"

module RailsAgentHarness
  # Command line entry point. Returns exit codes rather than calling exit, so the
  # whole thing is testable without forking.
  class CLI
    USAGE = <<~TEXT
      usage: rails-agent-harness <command> [options]

      commands:
        install    vendor the harness into this project and link the editor directories
        check      verify the vendored harness against this gem (use in CI)
        update     re-vendor and report what changed
        root       print the payload directory inside this gem
        version    print the gem version

      options:
        --path PATH    project root (default: current directory)
        --mode MODE    link (default) or copy, for filesystems without symlinks
        --no-migrate   leave existing .claude/.cursor content alone and fail instead

      On install, skills, rules, and agents already in .claude/ or .cursor/ are
      moved into #{PAYLOAD_DIR}/ first, so the symlinks cannot shadow or delete them.
    TEXT

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
      @options = { path: Dir.pwd, mode: :link, migrate: true }
    end

    def run
      command = parse!
      return usage(1) if command.nil?

      case command
      when "install" then install
      when "update" then update
      when "check" then check
      when "root" then @out.puts(RailsAgentHarness.payload) || 0
      when "version" then @out.puts(VERSION) || 0
      when "help" then usage(0)
      else
        @err.puts "unknown command: #{command}"
        usage(1)
      end
    rescue Error, OptionParser::ParseError => e
      @err.puts "error: #{e.message}"
      1
    end

    private

    def parse!
      parser = OptionParser.new do |o|
        o.on("--path PATH") { |v| @options[:path] = v }
        o.on("--mode MODE") { |v| @options[:mode] = v.to_sym }
        o.on("--[no-]migrate") { |v| @options[:migrate] = v }
        o.on("-h", "--help") { @argv.unshift("help") }
      end
      rest = parser.parse(@argv)
      rest.first
    end

    def installer
      Installer.new(project_root: @options[:path], mode: @options[:mode],
                    migrate: @options[:migrate], out: @out)
    end

    def install(label: "installed")
      result = installer.install
      return 1 unless report_blockers(result)

      summary = "#{label} #{result.written.size} file(s) into #{PAYLOAD_DIR}/"
      summary += ", #{result.unchanged.size} already current" unless result.unchanged.empty?
      @out.puts summary
      report_migration(result.migrated)
      report("kept local edits to", result.overridden)
      report("removed no-longer-shipped", result.pruned)
      result.links.each { |line| @out.puts "  #{line}" }
      0
    end

    def update
      install(label: "updated")
    end

    def check
      status, findings = installer.check

      case status
      when :uninstalled
        @err.puts "no harness found in #{@options[:path]} — run `rails-agent-harness install`"
        1
      when :ok
        @out.puts "harness #{VERSION} matches this gem"
        report("local override", findings.grep(/^overridden:/))
        0
      else
        @err.puts "harness has drifted from this gem:"
        findings.each { |f| @err.puts "  #{f}" }
        1
      end
    end

    # Both blockers stop the install before anything is written or moved.
    def report_blockers(result)
      return true if result.clean?

      result.migration_clashes.each do |clash|
        @err.puts "cannot move #{clash.from}/#{File.basename(clash.relative)} — " \
                  "#{PAYLOAD_DIR}/#{clash.relative} already exists with different content"
      end
      result.collisions.each { |r| @err.puts "refusing to overwrite #{PAYLOAD_DIR}/#{r} — this gem does not own it" }
      @err.puts "rename the app's version, or delete it to accept the harness copy."
      false
    end

    def report_migration(moves)
      return if moves.empty?

      @out.puts "  moved #{moves.size} existing item(s) into #{PAYLOAD_DIR}/ so the links cannot shadow them:"
      moves.first(10).each { |m| @out.puts "    #{m.from}/#{File.basename(m.relative)} -> #{PAYLOAD_DIR}/#{m.relative}" }
      @out.puts "    … and #{moves.size - 10} more" if moves.size > 10
    end

    def report(label, items)
      return if items.empty?

      @out.puts "  #{label}: #{items.size}"
      items.first(10).each { |item| @out.puts "    #{item}" }
      @out.puts "    … and #{items.size - 10} more" if items.size > 10
    end

    def usage(code)
      (code.zero? ? @out : @err).puts USAGE
      code
    end
  end
end
