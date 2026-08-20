# frozen_string_literal: true

require "optparse"
require "json"
require_relative "../agent_harness_rails"
require_relative "installer"
require_relative "evals"
require_relative "guard"

module AgentHarnessRails
  # Command line entry point. Returns exit codes rather than calling exit, so the
  # whole thing is testable without forking.
  class CLI
    FORMATS = %w[text json].freeze

    USAGE = <<~TEXT
      usage: agent_harness_rails <command> [options]

      commands:
        install    vendor the harness into this project and link the editor directories
        check      verify the vendored harness against this gem (use in CI)
        update     re-vendor and report what changed
        evals      check every intent clause in docs/primitives/ is proven by a spec (use in CI)
        guard      report what this change did to intent and the specs that prove it
        version    print the gem version

      options:
        --path PATH      project root (default: current directory)
        --mode MODE      install/update: link (default) or copy, for filesystems without symlinks
        --no-migrate     install/update: leave existing .claude/.cursor content alone and fail instead
        --format FORMAT  evals/guard: text (default) or json
        --base REF       guard: revision to compare against (default: HEAD)
        -h, --help       print this help

      examples:
        agent_harness_rails install                  # from the project root
        agent_harness_rails install --path ../myapp  # from anywhere
        agent_harness_rails install --mode copy      # e.g. a mounted volume without symlinks
        agent_harness_rails check                    # in CI: exits 1 on drift
        agent_harness_rails update                   # after bumping the gem
        agent_harness_rails evals                    # in CI: exits 1 on unproven intent
        agent_harness_rails guard                    # what this turn changed about intent
        agent_harness_rails guard --base main        # what this branch changed

      On install, skills, rules, and agents already in .claude/ or .cursor/ are
      moved into #{PAYLOAD_DIR}/ first, so the symlinks cannot shadow or delete
      them. Local edits to vendored files are kept; `check` reports them as
      overridden without failing.

      Guard answers the question evals cannot: not "is every clause hooked up to a
      spec" but "did this change quietly reword a promise, delete one, or hollow
      out the example proving it". It parses the tree twice — at --base and in the
      working tree — and reports what got smaller or different. Growth is silent.

      Every guard finding is a notice and the exit code is 0 whenever the
      comparison ran: each check has a legitimate cause as well as a suspicious
      one, and a check that stops honest work gets routed around. An agent
      reading its own notices should restore proof it dropped by accident; it
      should not write the provenance line that discharges an intent notice —
      that decision is the user's.

      Evals reads intent clauses from each capability doc's YAML frontmatter and
      the `intent: "<capability>#I<n>"` metadata on spec examples; the same tag
      runs the proof: rspec --tag 'intent:comment_threads#I2'. Tags belong on the
      example, not the group around it. Every active clause on a built doc must
      name a spec; the one warning that does not fail is a doc mid-amendment,
      whose plan has landed ahead of its code.
    TEXT

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
      @options = { path: Dir.pwd, mode: :link, migrate: true, format: "text", base: Guard::DEFAULT_BASE }
    end

    def run
      command = parse!
      return usage(1) if command.nil?

      case command
      when "install" then install
      when "update" then update
      when "check" then check
      when "evals" then evals
      when "guard" then guard
      when "version" then say(VERSION)
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

    def say(text)
      @out.puts(text)
      0
    end

    # OptionParser#parse works on a dup of the array, so the -h callback sets a
    # flag rather than mutating @argv, which the parser would never see.
    def parse!
      help = false
      parser = OptionParser.new do |o|
        o.on("--path PATH") { |v| @options[:path] = v }
        o.on("--mode MODE") { |v| @options[:mode] = v.to_sym }
        o.on("--[no-]migrate") { |v| @options[:migrate] = v }
        o.on("--format FORMAT") { |v| @options[:format] = v }
        o.on("--base REF") { |v| @options[:base] = v }
        o.on("-h", "--help") { help = true }
      end
      rest = parser.parse(@argv)
      return "help" if help

      # A stray argument is a typo, not a request for the default behaviour.
      raise Error, "unexpected argument: #{rest[1]}" if rest.size > 1

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
      report_link_notes(result) if @options[:mode] == :link
      0
    end

    # Both notes are one git rule with two faces: a pathspec may not traverse a
    # symlink. So new files have to be staged at their real path, and a migrated
    # file git tracked at its old path — now beneath a link, unnameable — can only
    # have its deletion staged in bulk. Said here, because this is the moment the
    # links appear and the moves have just happened.
    def report_link_notes(result)
      @out.puts "  note: author new skills, rules, and agents under #{PAYLOAD_DIR}/ — git cannot stage a path through a link"
      return if result.migrated.empty?

      @out.puts "        commit this install with `git add -A`: git tracked the moved files at paths it can no longer name"
    end

    def update
      install(label: "updated")
    end

    def evals
      validate_format!
      result = Evals.run(root: File.expand_path(@options[:path]))
      @options[:format] == "json" ? evals_json(result) : evals_text(result)
      result.ok? ? 0 : 1
    end

    def validate_format!
      return if FORMATS.include?(@options[:format])

      raise Error, "format must be text or json, not #{@options[:format].inspect}"
    end

    # Always 0 when the comparison ran. Guard reports; it does not judge, and a
    # non-zero exit here would turn every notice into a gate.
    def guard
      validate_format!
      result = Guard.run(root: File.expand_path(@options[:path]), base: @options[:base])
      @options[:format] == "json" ? guard_json(result) : guard_text(result)
      0
    end

    def guard_text(result)
      result.findings.each { |finding| @out.puts finding }
      @out.puts if result.findings.any?
      @out.puts "compared against #{short(result.base)}: #{guard_summary(result)}"
    end

    def guard_summary(result)
      return "no change to intent or the specs that prove it" if result.clean?

      "#{pluralize(result.findings.size, 'notice')} for review — none of this fails the run"
    end

    def guard_json(result)
      @out.puts JSON.pretty_generate(
        base: result.base, capabilities: result.capabilities,
        notices: result.findings.size, findings: result.findings.map(&:to_h)
      )
    end

    def short(ref) = ref[0, 12]

    def evals_text(result)
      result.findings.each { |finding| @out.puts finding }
      @out.puts if result.findings.any?
      @out.puts evals_summary(result)
    end

    def evals_summary(result)
      warnings = result.findings.size - result.errors.size
      counted = [ "#{pluralize(result.capabilities, 'capability', 'capabilities')} inspected",
                  pluralize(result.clauses, "clause") ]
      counted << (result.findings.empty? ? "no offences" : "#{pluralize(result.errors.size, 'offence')} detected")
      counted << pluralize(warnings, "warning") if warnings.positive?
      counted.join(", ")
    end

    def evals_json(result)
      @out.puts JSON.pretty_generate(
        capabilities: result.capabilities, clauses: result.clauses,
        errors: result.errors.size, findings: result.findings.map(&:to_h)
      )
    end

    def pluralize(count, singular, plural = "#{singular}s")
      "#{count} #{count == 1 ? singular : plural}"
    end

    def check
      status, findings = installer.check

      case status
      when :uninstalled
        @err.puts "no harness found in #{@options[:path]} — run `agent_harness_rails install`"
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
