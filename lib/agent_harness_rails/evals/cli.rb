# frozen_string_literal: true

require "optparse"
require "json"
require_relative "../evals"

module AgentHarnessRails
  module Evals
    # Command line entry point for `rails-evals`. Returns exit codes rather than
    # calling exit, so the whole thing is testable without forking — same shape
    # as AgentHarnessRails::CLI.
    class CLI
      USAGE = <<~TEXT
        usage: rails-evals [options]

        Checks that every intent clause in #{DEFAULT_PRIMITIVES_DIR}/ is proven by a spec,
        and that every `intent:` tag in the suite names a clause that exists.

        options:
          --path PATH          project root (default: current directory)
          --primitives DIR     primitives tree, relative to the root (default: #{DEFAULT_PRIMITIVES_DIR})
          --specs DIR          spec suite, relative to the root (default: #{DEFAULT_SPECS_DIR})
          --format FORMAT      text (default) or json
          -v, --version        print the gem version
          -h, --help           print this help

        Clauses are declared in each capability doc's YAML frontmatter and proven by
        RSpec metadata on the examples:

          it "shows replies nested under their parent", intent: "comment_threads#I2"

        The same tag runs the proof: rspec --tag 'intent:comment_threads#I2'

        Exits 1 when there are errors. Warnings — an `unproven:` clause, a doc
        mid-amendment — are reported without failing the run.
      TEXT

      def initialize(argv, out: $stdout, err: $stderr)
        @argv = argv.dup
        @out = out
        @err = err
        @options = { path: Dir.pwd, primitives: DEFAULT_PRIMITIVES_DIR,
                     specs: DEFAULT_SPECS_DIR, format: "text" }
      end

      def run
        return usage(0) if parse! == :help
        return say(VERSION) if @options[:version]

        report Evals.run(root: File.expand_path(@options[:path]),
                         primitives_dir: @options[:primitives],
                         specs_dir: @options[:specs])
      rescue Error, OptionParser::ParseError => e
        @err.puts "error: #{e.message}"
        1
      end

      private

      def say(text)
        @out.puts(text)
        0
      end

      # Matches AgentHarnessRails::CLI: OptionParser#parse works on a dup, so the
      # -h callback sets a flag rather than mutating @argv.
      def parse!
        help = false
        parser = OptionParser.new do |o|
          o.on("--path PATH") { |v| @options[:path] = v }
          o.on("--primitives DIR") { |v| @options[:primitives] = v }
          o.on("--specs DIR") { |v| @options[:specs] = v }
          o.on("--format FORMAT") { |v| @options[:format] = v }
          o.on("-v", "--version") { @options[:version] = true }
          o.on("-h", "--help") { help = true }
        end
        parser.parse(@argv)
        help ? :help : nil
      end

      def report(result)
        @options[:format] == "json" ? report_json(result) : report_text(result)
        result.ok? ? 0 : 1
      end

      def report_text(result)
        result.findings.each { |finding| @out.puts finding }
        @out.puts if result.findings.any?
        @out.puts summary(result)
      end

      def summary(result)
        warnings = result.findings.size - result.errors.size
        counted = [ "#{pluralize(result.capabilities, 'capability', 'capabilities')} inspected",
                    pluralize(result.clauses, "clause") ]
        counted << (result.findings.empty? ? "no offences" : "#{pluralize(result.errors.size, 'offence')} detected")
        counted << "#{pluralize(warnings, 'warning')}" if warnings.positive?
        counted.join(", ")
      end

      def report_json(result)
        @out.puts JSON.pretty_generate(
          capabilities: result.capabilities, clauses: result.clauses,
          errors: result.errors.size, findings: result.findings.map(&:to_h)
        )
      end

      def pluralize(count, singular, plural = "#{singular}s")
        "#{count} #{count == 1 ? singular : plural}"
      end

      def usage(code)
        (code.zero? ? @out : @err).puts USAGE
        code
      end
    end
  end
end
