# frozen_string_literal: true

require "optparse"
require "json"
require_relative "../agent_harness_rails"
require_relative "installer"
require_relative "evals"
require_relative "guard"
require_relative "proof_report"

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
        proofs     list the examples proving each intent clause
        version    print the gem version

      options:
        --path PATH      project root (default: current directory)
        --mode MODE      install/update: link (default) or copy, for filesystems without symlinks
        --no-migrate     install/update: leave existing .claude/.cursor content alone and fail instead
        --format FORMAT  evals/guard/proofs: text (default) or json
        --base REF       guard: revision to compare against (default: HEAD)
        --since REF      proofs: only clauses whose spec files this change touched
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
        agent_harness_rails proofs                   # one line per clause
        agent_harness_rails proofs orders            # a capability, with its proving examples
        agent_harness_rails proofs 'orders#I3'       # one clause, with its proving examples
        agent_harness_rails proofs --since main      # the clauses this branch's specs touch

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

      Proofs answers a third question, and is a lookup rather than a check: which
      examples prove this clause. Evals is satisfied by one tag per file, so a
      clause the plan meant to prove with four denials passes with three tagged —
      the tagged listing is what a verify step compares against the plan's proof
      set, and a planned example missing from it is found in the spec file and
      tagged, or written. Nothing here is an offence and the exit code is always
      0: most examples in a spec file carry no tag by design, so a tagged count
      is a number to compare with the plan, not a verdict. A tag on a `describe`
      is named as proving nothing rather than shown among the proofs, and the
      footer counts every tag evals will reject. --format json additionally
      carries every untagged example in the files a clause names.

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
      when "proofs" then proofs
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
        o.on("--since REF") { |v| @options[:since] = v }
        o.on("-h", "--help") { help = true }
      end
      rest = parser.parse(@argv)
      return "help" if help

      # A stray argument is a typo, not a request for the default behaviour. The
      # one command that takes a positional is `proofs`, whose argument is the
      # capability or clause to report on.
      command, *positional = rest
      @options[:scope] = positional.shift if command == "proofs"
      raise Error, "unexpected argument: #{positional.first}" if positional.any?

      command
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
      findings_text(result.findings)
      @out.puts "compared against #{short(result.base)}: #{guard_summary(result)}"
    end

    # Findings grouped under one path header per file, so a burst of notices in
    # one file reads as a block rather than a wall of repeated paths.
    def findings_text(findings)
      findings.group_by(&:path).each do |path, group|
        @out.puts path
        width = group.map { |finding| position(finding).length }.max
        group.each { |finding| finding_text(finding, width) }
        @out.puts
      end
    end

    def position(finding) = "#{finding.line}:#{finding.column}"

    def finding_text(finding, width)
      @out.puts "  #{position(finding).ljust(width)}   #{paint(finding.letter, severity_colour(finding))}  " \
                "#{finding.message}   [#{finding.code}]"
      (finding.details || []).each { |detail| detail_text(detail, width) }
    end

    # Indented to sit under the severity letter. Labelled lines are clause text
    # and get clipped; `--format json` carries them whole.
    def detail_text(detail, width)
      indent = " " * (width + 5)
      body = detail.label ? "#{detail.label}:  #{clip(detail.text)}" : detail.text
      @out.puts "  #{indent}#{body}"
    end

    def clip(text, limit: 100)
      text.length > limit ? "#{text[0, limit - 1]}…" : text
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

    # Always 0. Proofs reports what proves what; the verdict on whether that is
    # enough belongs to `evals` and to review.
    def proofs
      validate_format!
      result = ProofReport.run(root: File.expand_path(@options[:path]), scope: @options[:scope],
                               since: @options[:since])
      @options[:format] == "json" ? proofs_json(result) : proofs_text(result)
      0
    end

    def proofs_text(result)
      return @out.puts(nothing_to_report(result)) if result.empty?

      result.detail == :summary ? proofs_summary(result) : proofs_detail(result)
      @out.puts
      proofs_misplaced(result)
      proofs_footer(result)
    end

    def nothing_to_report(result)
      return "no spec file proving an intent clause changed since #{short(result.base)}" if result.base

      "no intent clauses found — `agent_harness_rails evals` explains what a capability doc needs"
    end

    # One line per clause under its capability: the health-pass density, which
    # stays scannable at two hundred clauses. Whether a count is the *right*
    # count is a question for the plan, so drilling in is a second command
    # rather than more output here.
    def proofs_summary(result)
      each_capability(result) do |rows|
        width = rows.map { |row| clause_line(row).length }.max
        rows.each { |row| @out.puts "#{clause_line(row).ljust(width)}    #{clause_summary(row)}" }
      end
    end

    def each_capability(result)
      result.rows.group_by(&:capability).each_with_index do |(capability, rows), index|
        @out.puts if index.positive?
        @out.puts "#{capability} (#{rows.first.status || 'no status'})"
        yield rows
      end
    end

    def clause_line(row) = "  #{row.clause.id}  #{row.clause.text}"

    def clause_summary(row)
      return inactive_summary(row) if row.state
      return "no evaluations" if row.files.empty?

      count = pluralize(row.tagged, "tagged example")
      row.tagged.zero? ? paint(count, 31) : count
    end

    # A tag on a superseded or retired clause is still a real example, and one
    # `evals` calls an offence — so the count is shown rather than swallowed by
    # the state, and the footer's total reconciles with the rows above it.
    def inactive_summary(row)
      return row.state if row.tagged.zero?

      "#{row.state} — #{pluralize(row.tagged, 'example')} still tagged"
    end

    def proofs_detail(result)
      each_capability(result) do |rows|
        rows.each { |row| proofs_clause(row) }
      end
    end

    def proofs_clause(row)
      state = row.state ? "  [#{row.state}]" : ""
      @out.puts
      @out.puts "  #{paint(row.clause.id, 1)}  #{row.clause.text}#{state}"
      return @out.puts "      no evaluations" if row.files.empty?

      row.files.each { |file| proofs_file(file) }
    end

    def proofs_file(file)
      return @out.puts "      #{file.path}  (file not found)" unless file.exists

      undeclared = file.declared ? "" : "  (not in this clause's `evaluations:`)"
      count = pluralize(file.tagged.size, "tagged example")
      @out.puts "      #{file.path} — #{file.tagged.empty? ? paint(count, 31) : count}#{undeclared}"
      proofs_examples(file.tagged)
    end

    def proofs_examples(tagged)
      return if tagged.empty?

      openers = tagged.map { |proof| ":#{proof.opener}" }
      described = tagged.map { |proof| description(proof.description) }
      opener_width = openers.map(&:length).max
      description_width = described.map(&:length).max

      tagged.each_with_index do |proof, index|
        @out.puts "        #{openers[index].ljust(opener_width)}  #{described[index].ljust(description_width)}" \
                  "    #{pluralize(proof.assertions, 'assertion')}"
      end
    end

    # A tag on a group has no example under it, so it never appears among the
    # proofs — it is named for what it is instead, with its address. Deduplicated
    # because one file can prove several of the listed clauses.
    def proofs_misplaced(result)
      tags = result.rows.flat_map do |row|
        row.files.flat_map { |file| file.misplaced.map { |proof| [ file.path, proof.line, proof.group ] } }
      end.uniq
      return if tags.empty?

      tags.each do |path, line, group|
        @out.puts "tag proving nothing: #{path}:#{line} sits on `#{group}` — no example under it"
      end
      @out.puts
    end

    def description(text) = text.to_s.strip.empty? ? "(no description)" : text

    def proofs_footer(result)
      parts = [ pluralize(result.rows.size, "clause"), pluralize(result.tagged, "tagged example") ]
      parts << "in files changed since #{short(result.base)}" if result.base
      @out.puts parts.join(", ")
      @out.puts unusable_summary(result.unusable) unless result.unusable.values.sum.zero?
    end

    # Every kind gets a line's worth of mention, so the report never looks like
    # the whole picture when some of the suite's tags are not proof at all.
    UNUSABLE = { unresolved: "naming no active clause", misplaced: "on a group rather than an example",
                 malformed: "not in `<capability>#I<n>` form" }.freeze

    def unusable_summary(unusable)
      total = unusable.values.sum
      named = UNUSABLE.filter_map { |kind, phrase| [ unusable[kind], phrase ] unless unusable[kind].zero? }
      count = "#{pluralize(total, 'tag')} in the suite #{total == 1 ? 'is' : 'are'}"
      tail = "`agent_harness_rails evals` reports #{total == 1 ? 'it' : 'each'}"
      return "#{count} #{named.first.last} — #{tail}" if named.one?

      "#{count} not usable proof — #{named.map { |n, phrase| "#{n} #{phrase}" }.join(', ')}; #{tail}"
    end

    def proofs_json(result)
      @out.puts JSON.pretty_generate(
        scope: result.scope, base: result.base, detail: result.detail,
        capabilities: result.capabilities, clauses: result.rows.size,
        tagged_examples: result.tagged, unresolved_tags: result.unusable[:unresolved],
        misplaced_tags: result.unusable[:misplaced], malformed_tags: result.unusable[:malformed],
        proofs: result.rows.map(&:to_h)
      )
    end

    def evals_text(result)
      findings_text(result.findings)
      @out.puts evals_summary(result)
    end

    def evals_summary(result)
      warnings = result.findings.size - result.errors.size
      counted = [ pluralize(result.capabilities, "capability", "capabilities"),
                  pluralize(result.clauses, "clause") ]
      tail = result.findings.empty? ? "no offences" : pluralize(result.errors.size, "offence")
      tail += ", #{pluralize(warnings, 'warning')}" if warnings.positive?
      "#{counted.join(', ')} — #{tail}"
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

    SEVERITY_COLOURS = { "E" => 31, "W" => 33, "N" => 33 }.freeze

    def severity_colour(finding) = SEVERITY_COLOURS[finding.letter]

    # Colour only when a person is watching: a TTY without NO_COLOR set. Piped
    # output — CI logs, agents, redirects — gets exactly the plain text.
    def paint(text, code)
      colour? && code ? "\e[#{code}m#{text}\e[0m" : text
    end

    def colour?
      return @colour if defined?(@colour)

      @colour = @out.respond_to?(:tty?) && @out.tty? && ENV["NO_COLOR"].to_s.empty?
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
