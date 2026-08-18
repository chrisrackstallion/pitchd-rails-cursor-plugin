# frozen_string_literal: true

module AgentHarnessRails
  module Evals
    # Every `intent:` metadata tag in the spec suite.
    #
    #   it "shows replies nested under their parent", intent: "comment_threads#I2" do
    #   it "nests three deep", intent: %w[comment_threads#I2 comment_threads#I3] do
    #
    # Real RSpec metadata rather than a comment, so the same tag that binds the
    # clause also selects the proof:
    #
    #   bundle exec rspec --tag 'intent:comment_threads#I2'
    #
    # A tag belongs on the example, never on the group around it — see
    # PLACEMENT below.
    #
    # Scanned textually rather than by booting RSpec: this must run in any CI
    # job, with no database and no Rails environment. The honest cost is that a
    # tag inside commented-out or unreachable code still counts — the same
    # trade-off bin/check-references makes. A tag that resolves here but whose
    # example no longer runs is caught by the suite itself going red, not here.
    module Tags
      # `intent:` followed by one string, a %w list, or a bracketed list.
      PATTERN = /
        \bintent:\s*
        (?:
          %[wi]\[(?<list>[^\]]*)\]
          | \[(?<bracketed>[^\]]*)\]
          | (?<quote>["'])(?<single>[^"']*)\k<quote>
        )
      /x
      QUOTED = /["']([^"']+)["']/

      # Placement: the tag must sit on the example that proves the clause.
      #
      # A group tag looks like the tidier option — one line standing for four
      # examples — and it is the one form that can go on lying. Delete the
      # example the tag was really for, and its siblings keep the group green;
      # `rspec --tag` still returns passing examples, and the clause still
      # claims a proof that no longer exists. Per-example tags cost a repeated
      # line and buy the loud break: the last one goes, and the clause fails as
      # unproven.
      #
      # Longest-first alternation so `its` is not shadowed by `it`. The
      # `[fx]` prefix catches `fit`, `xdescribe` and friends — a focused or
      # skipped example is still an example for placement purposes; whether it
      # should carry a tag at all is rubocop-rspec's argument to have.
      EXAMPLE_METHODS = %w[specify scenario example its it].freeze
      GROUP_METHODS = %w[shared_examples_for shared_examples shared_context describe context feature].freeze
      OPENER = /^[ \t]*(?:RSpec\.)?[fx]?(?<method>#{(EXAMPLE_METHODS + GROUP_METHODS).join('|')})[\s(]/

      # How far back to look for the call a tag is metadata for. Almost always
      # the tag's own line; a couple more covers metadata wrapped onto its own
      # line under a long example name. Past that the scan gives up rather than
      # guess — an unclassified tag is reported as nothing, not as an offence.
      LOOKBACK = 3

      Tag = Struct.new(:capability, :clause_id, :path, :line, :column, keyword_init: true) do
        def to_s = "#{capability}##{clause_id}"
      end

      # Returns [ tags, findings ] — findings covering values that are not
      # `<capability>#I<n>`, and tags sitting on a group rather than an example.
      # The IntentTag cop catches both at lint time for apps running the harness
      # RuboCop layer.
      #
      # A misplaced tag is still returned as a tag: it names a real clause, and
      # reporting it a second time as an untagged evaluation would describe one
      # mistake twice.
      def self.scan(dir, root:)
        tags = []
        findings = []
        return [ tags, findings ] unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "**", "*_spec.rb")).sort.each do |path|
          relative = path.delete_prefix("#{root}/")
          lines = File.readlines(path, chomp: true, encoding: "UTF-8")

          lines.each_with_index do |line, index|
            line.to_enum(:scan, PATTERN).each do
              match = Regexp.last_match
              column = match.begin(0) + 1

              values(match).each do |value|
                tag = parse(value, relative, index + 1, column)
                next findings << malformed(value, relative, index + 1, column) if tag.nil?

                tags << tag
                group = enclosing_group(lines, index)
                findings << misplaced(tag, group, column) if group
              end
            end
          end
        end

        [ tags, findings ]
      end

      # The group method this tag is metadata for, or nil when it sits on an
      # example or on nothing this scan can name.
      def self.enclosing_group(lines, index)
        index.downto([ index - LOOKBACK, 0 ].max) do |candidate|
          match = OPENER.match(lines[candidate])
          next unless match

          return GROUP_METHODS.include?(match[:method]) ? match[:method] : nil
        end

        nil
      end

      def self.values(match)
        return match[:list].split if match[:list]
        return match[:bracketed].scan(QUOTED).flatten if match[:bracketed]

        [ match[:single] ]
      end

      def self.parse(value, path, line, column)
        capability, clause_id = value.split("#", 2)
        return nil unless clause_id && Capability::CLAUSE_ID.match?(clause_id) && !capability.to_s.empty?

        Tag.new(capability: capability, clause_id: clause_id, path: path, line: line, column: column)
      end

      def self.malformed(value, path, line, column)
        Finding.new(severity: :error, path: path, line: line, column: column,
                    message: "intent tag #{value.inspect} is not in `<capability>#I<n>` form",
                    code: "tag/malformed")
      end

      def self.misplaced(tag, group, column)
        Finding.new(severity: :error, path: tag.path, line: tag.line, column: column,
                    message: "intent tag #{tag.to_s.inspect} is on `#{group}` — tag the example that " \
                             "proves the clause, or the tag outlives the example it stood for",
                    code: "tag/misplaced")
      end

      private_class_method :values, :parse, :malformed, :misplaced, :enclosing_group
    end
  end
end
