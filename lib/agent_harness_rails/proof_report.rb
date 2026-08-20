# frozen_string_literal: true

require "open3"
require_relative "../agent_harness_rails"
require_relative "evals"
require_relative "guard/baseline"

module AgentHarnessRails
  # Lists the examples that prove each intent clause, and — the part no other
  # command can see — how many of the examples in an evaluation file carry the
  # tag.
  #
  # `Evals` is a gate whose unit of coverage is the **file**: a clause naming
  # `spec/policies/long_list_policy_spec.rb` is satisfied the moment *one*
  # example in that file carries the tag. So a clause the plan meant to prove
  # with four denials, three of which got tagged, passes — and `Guard` is silent
  # too, because an untagged new example is growth and growth is silent there by
  # design. The rule those two leave unenforced is the one in
  # `agent_harness_rails/rules/testing.mdc` § Tagging the Intent a Spec Proves:
  # a clause proven by four examples is tagged on all four.
  #
  # This closes that gap as a **report**, not a gate. Exit code is always 0 and
  # nothing here is a finding: most examples in a spec file legitimately carry no
  # tag ("only evaluation examples are tagged"), so `3 of 7` is a number for a
  # reader to compare against the plan's proof set, never an offence. Made an
  # offence it would fire on almost every file and get routed around.
  #
  # Textual, like the tag scan: it must run with no database and no Rails
  # environment. `rspec --tag 'intent:x#I1'` can list the tagged examples but
  # needs the whole app booted, and it structurally cannot report the *untagged*
  # siblings — which is the entire signal.
  module ProofReport
    # Scope, and with it output density. Unscoped is a health pass over the whole
    # tree, so it stays one line per clause; naming a clause is a question about
    # that clause, so it earns the untagged listing that would be noise across
    # two hundred of them.
    SCOPE = /\A(?<capability>[a-z0-9_]+)(?:#(?<clause>I[1-9]\d*))?\z/

    # One file a clause is proven in: its examples, which of them carry the tag,
    # and which do not.
    Coverage = Struct.new(:path, :declared, :exists, :examples, :tagged, :untagged, :misplaced,
                          keyword_init: true) do
      # "carry this tag" rather than "tagged": the difference between the total
      # and the numerator is not all untagged — some of it is examples proving a
      # different clause in the same file.
      #
      # The noun agrees with the denominator and the verb with the numerator —
      # "1 of 2 examples carries this tag" — except that a zero numerator takes
      # the singular when the noun is singular, so the one file holding one
      # example does not read "0 of 1 example carry". This line is the report;
      # it is worth the two conditions.
      def ratio
        singular = tagged.size == 1 || (tagged.size.zero? && examples == 1)

        "#{tagged.size} of #{examples} example#{'s' unless examples == 1} " \
          "#{singular ? 'carries' : 'carry'} this tag"
      end

      def to_h
        { path: path, declared: declared, exists: exists, examples: examples,
          tagged: tagged.map { |proof| { line: proof.opener, description: proof.description, assertions: proof.assertions } },
          untagged: untagged.map { |example| { line: example.line, description: example.description } },
          misplaced: misplaced.map { |proof| { line: proof.line, group: proof.group } } }
      end
    end

    # One clause and everywhere it is proven.
    Row = Struct.new(:capability, :status, :clause, :files, keyword_init: true) do
      def id = "#{capability}##{clause.id}"

      def tagged = files.sum { |file| file.tagged.size }

      def state
        return "superseded by #{clause.superseded_by.join(', ')}" unless clause.superseded_by.empty?

        clause.retired_on ? "retired #{clause.retired_on}" : nil
      end

      def to_h
        { capability: capability, clause_id: clause.id, clause: clause.text, status: status,
          active: clause.active?, state: state, files: files.map(&:to_h) }
      end
    end

    Result = Struct.new(:rows, :scope, :detail, :capabilities, :unusable, :base, keyword_init: true) do
      def tagged = rows.sum(&:tagged)

      def empty? = rows.empty?
    end

    class << self
      def run(root:, scope: nil, since: nil, primitives_dir: Evals::DEFAULT_PRIMITIVES_DIR,
              specs_dir: Evals::DEFAULT_SPECS_DIR)
        capabilities_dir = File.join(root, primitives_dir, Evals::CAPABILITIES_SUBDIR)
        raise Error, "no capability docs at #{primitives_dir}/#{Evals::CAPABILITIES_SUBDIR}/" unless Dir.exist?(capabilities_dir)

        target = parse_scope(scope)
        capabilities = Evals::Capability.load_all(capabilities_dir, root: root)
        tags, findings = Evals::Tags.scan(File.join(root, specs_dir), root: root)
        found = Evals::Proofs.read(tags, root: root)

        rows = build_rows(capabilities, found.group_by(&:clause_key),
                          found.group_by(&:path).transform_values { |list| list.map(&:opener) }, root: root)
        base, touched = since ? changed_paths(root, since) : [ nil, nil ]

        Result.new(rows: select(rows, target, touched, primitives_dir),
                   scope: scope, detail: detail_for(target, since), capabilities: capabilities.size,
                   unusable: unusable(capabilities, tags, findings), base: base)
      end

      private

      def parse_scope(scope)
        return nil if scope.nil?

        match = SCOPE.match(scope)
        raise Error, "scope #{scope.inspect} reads `<capability>` or `<capability>#I<n>`, e.g. comment_threads#I2" if match.nil?

        [ match[:capability], match[:clause] ]
      end

      # `--since` gets the untagged listing too: it asks the same question naming
      # a clause asks — did this change tag everything it meant to — answered for
      # every clause the change touched, and it is the shape a task's verify step
      # runs. Bounded by the change, not by the size of the tree.
      def detail_for(target, since)
        return :full if target&.last || since
        return :files if target

        :summary
      end

      def build_rows(capabilities, proofs, tagged_lines, root:)
        lines = {}

        capabilities.flat_map do |capability|
          capability.clauses.map do |clause|
            Row.new(capability: capability.name, status: capability.status, clause: clause,
                    files: coverage(clause, proofs[[ capability.name, clause.id ]] || [],
                                    tagged_lines, lines, root: root))
          end
        end
      end

      # Union of what the clause declares and where its tags actually are: a tag
      # in a file the clause does not list is real proof, and hiding it would
      # describe the suite as thinner than it is. `declared` carries which is
      # which — `evals` is the one that calls the undeclared case an offence.
      def coverage(clause, proofs, tagged_lines, lines, root:)
        found = proofs.group_by(&:path)

        (clause.evaluations | found.keys).sort.map do |relative|
          # A tag on a `describe` has no example around it, so everything read
          # from it describes the group line. Kept out of `tagged` for that
          # reason: counting it would put a phantom in the numerator of a ratio
          # someone is about to hold against a plan.
          misplaced, tagged = (found[relative] || []).sort_by(&:opener).partition(&:misplaced?)
          examples = lines[relative] ||= read(File.join(root, relative))
          next missing(relative, tagged, misplaced) if examples.nil?

          # Anything carrying *any* intent tag is excluded, not just this
          # clause's: an example proving a sibling clause is not a candidate this
          # change forgot to tag, and listing it as one would send a reader to
          # check work that is already done.
          carried = tagged_lines[relative] || []

          Coverage.new(path: relative, declared: clause.evaluations.include?(relative), exists: true,
                       examples: examples.size, tagged: tagged, misplaced: misplaced,
                       untagged: examples.reject { |example| carried.include?(example.line) })
        end
      end

      # nil for a file the clause names and the app does not have — read once per
      # file however many clauses it proves.
      def read(path)
        return nil unless File.exist?(path)

        Evals::Proofs.examples(File.readlines(path, chomp: true, encoding: "UTF-8"))
      end

      def missing(relative, tagged, misplaced)
        Coverage.new(path: relative, declared: true, exists: false, examples: 0, tagged: tagged,
                     untagged: [], misplaced: misplaced)
      end

      def select(rows, target, touched, primitives_dir)
        rows = rows.select { |row| row.capability == target.first } if target
        rows = rows.select { |row| row.clause.id == target.last } if target&.last
        raise Error, "nothing named #{target.compact.join('#')} in #{primitives_dir}/" if target && rows.empty?

        touched ? rows.select { |row| row.files.any? { |file| touched.include?(file.path) } } : rows
      end

      # Clauses whose evaluation files this change touched, so the verify step of
      # one task does not have to enumerate the clauses it served. Untracked
      # files are included deliberately: a brand-new spec file carrying the first
      # tags for a clause is the commonest shape of the omission this reports.
      # Resolved through `Guard::Baseline` so `--since main` means the same thing
      # as `guard --base main`: where this work started, not where main has since
      # got to.
      def changed_paths(root, since)
        base = Guard::Baseline.resolve(root, since)
        paths = git(root, "diff", "--name-only", base).lines +
                git(root, "ls-files", "--others", "--exclude-standard").lines

        [ base, paths.map(&:strip).reject(&:empty?) ]
      end

      # No shell, so a branch name with a space or a `;` in it is an argument.
      def git(root, *args)
        out, err, status = Open3.capture3("git", "-C", root, *args)
        raise Error, "git #{args.first} failed: #{err.strip}" unless status.success?

        out
      end

      # Counted, not listed: every one of these is `evals`' offence to report, and
      # repeating the detail here would describe one mistake in two voices. The
      # counts are still worth a line — each kind is another way a clause ends up
      # proven by less than the plan said, and a reader who sees none of them
      # named would read this report as the whole picture.
      #
      # One label per tag, most disqualifying first: a tag naming nothing real is
      # reported as unresolved even when it also sits on a group, so the counts
      # sum to the number of unusable tags rather than double-counting.
      def unusable(capabilities, tags, findings)
        by_name = capabilities.to_h { |capability| [ capability.name, capability ] }
        unresolved, placed = tags.partition do |tag|
          clause = by_name[tag.capability]&.clause(tag.clause_id)
          clause.nil? || !clause.active?
        end

        { unresolved: unresolved.size, misplaced: placed.count(&:misplaced?),
          malformed: findings.count { |finding| finding.code == "tag/malformed" } }
      end
    end
  end
end
