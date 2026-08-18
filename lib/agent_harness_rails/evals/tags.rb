# frozen_string_literal: true

module AgentHarnessRails
  module Evals
    # Every `intent:` metadata tag in the spec suite.
    #
    #   it "shows replies nested under their parent", intent: "comment_threads#I2" do
    #   describe "threading", intent: %w[comment_threads#I2 comment_threads#I3] do
    #
    # Real RSpec metadata rather than a comment, so the same tag that binds the
    # clause also selects the proof:
    #
    #   bundle exec rspec --tag 'intent:comment_threads#I2'
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

      Tag = Struct.new(:capability, :clause_id, :path, :line, :column, keyword_init: true) do
        def to_s = "#{capability}##{clause_id}"
      end

      # Returns [ tags, findings ] — findings covering values that are not
      # `<capability>#I<n>`, which the IntentTag cop also catches at lint time
      # for apps running the harness RuboCop layer.
      def self.scan(dir, root:)
        tags = []
        findings = []
        return [ tags, findings ] unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "**", "*_spec.rb")).sort.each do |path|
          relative = path.delete_prefix("#{root}/")

          File.readlines(path, chomp: true, encoding: "UTF-8").each_with_index do |line, index|
            line.to_enum(:scan, PATTERN).each do
              match = Regexp.last_match
              column = match.begin(0) + 1

              values(match).each do |value|
                tag = parse(value, relative, index + 1, column)
                tag ? tags << tag : findings << malformed(value, relative, index + 1, column)
              end
            end
          end
        end

        [ tags, findings ]
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

      private_class_method :values, :parse, :malformed
    end
  end
end
