# frozen_string_literal: true

require_relative "../agent_harness_rails"
require_relative "evals/finding"
require_relative "evals/capability"
require_relative "evals/tags"

module AgentHarnessRails
  # Checks that every intent clause in docs/primitives/ is proven by a spec, and
  # that every intent tag in the suite names a clause that exists.
  #
  # Deliberately narrow: clause ↔ evaluation and nothing else, so a green run has
  # one unambiguous meaning. Tree health — index sync, size tripwires, orphan
  # docs, provenance style — stays with the maintaining-primitives skill, where
  # it needs judgment rather than a parser.
  module Evals
    DEFAULT_PRIMITIVES_DIR = "docs/primitives"
    DEFAULT_SPECS_DIR = "spec"
    CAPABILITIES_SUBDIR = "capabilities"

    Result = Struct.new(:findings, :capabilities, :clauses, keyword_init: true) do
      def errors = findings.select(&:error?)
      def ok? = errors.empty?
    end

    class << self
      def run(root:, primitives_dir: DEFAULT_PRIMITIVES_DIR, specs_dir: DEFAULT_SPECS_DIR)
        capabilities_dir = File.join(root, primitives_dir, CAPABILITIES_SUBDIR)
        raise Error, "no capability docs at #{primitives_dir}/#{CAPABILITIES_SUBDIR}/" unless Dir.exist?(capabilities_dir)

        capabilities = Capability.load_all(capabilities_dir, root: root)
        tags, findings = Tags.scan(File.join(root, specs_dir), root: root)

        findings += capabilities.flat_map(&:findings)
        findings += check_evaluations(capabilities, tags, root: root)
        findings += check_tags(capabilities, tags)

        Result.new(findings: sort(findings), capabilities: capabilities.size,
                   clauses: capabilities.sum { |c| c.clauses.size })
      end

      private

      # Doc → suite: does each clause name a spec, and does that spec carry the
      # tag it claims?
      def check_evaluations(capabilities, tags, root:)
        tagged = tags.group_by { |tag| [ tag.capability, tag.clause_id ] }

        capabilities.flat_map do |capability|
          capability.active_clauses.flat_map do |clause|
            coverage(capability, clause) +
              declared_paths(capability, clause, tagged, root: root)
          end
        end
      end

      def coverage(capability, clause)
        return [] unless capability.built?
        return [] unless clause.evaluations.empty?

        if clause.unproven?
          [ finding(:warning, capability, clause,
                    "#{clause.id} is marked unproven — a recorded test gap, not proof", "clause/unproven-accepted") ]
        elsif capability.in_flight?
          [ finding(:warning, capability, clause,
                    "#{clause.id} has no evaluation yet; this doc is mid-amendment", "clause/in-flight") ]
        else
          [ finding(:error, capability, clause,
                    "#{clause.id} has no evaluation — a built clause must name the spec that proves it", "clause/unproven") ]
        end
      end

      def declared_paths(capability, clause, tagged, root:)
        carriers = (tagged[[ capability.name, clause.id ]] || []).map(&:path)

        clause.evaluations.flat_map do |relative|
          if !File.exist?(File.join(root, relative))
            [ finding(:error, capability, clause, "#{clause.id} names #{relative}, which does not exist", "evaluation/missing-file") ]
          elsif !carriers.include?(relative)
            [ finding(:error, capability, clause,
                      "#{relative} carries no `intent: \"#{capability.name}##{clause.id}\"` tag", "evaluation/untagged") ]
          else
            []
          end
        end
      end

      # Suite → doc: does each tag name a clause that exists, is still active,
      # and lists this spec file?
      def check_tags(capabilities, tags)
        by_name = capabilities.to_h { |capability| [ capability.name, capability ] }

        tags.filter_map do |tag|
          capability = by_name[tag.capability]
          next unresolved(tag, "no capability doc is named #{tag.capability}.md") if capability.nil?

          clause = capability.clause(tag.clause_id)
          next unresolved(tag, "#{capability.name} defines no #{tag.clause_id}") if clause.nil?
          next unresolved(tag, "#{tag} is superseded or retired — retag or remove this example") unless clause.active?
          next if clause.evaluations.include?(tag.path)

          Finding.new(severity: :error, path: tag.path, line: tag.line, column: tag.column,
                      message: "#{tag} is not listed in that clause's `evaluations:`", code: "tag/undeclared")
        end
      end

      def unresolved(tag, message)
        Finding.new(severity: :error, path: tag.path, line: tag.line, column: tag.column,
                    message: "intent tag #{tag.to_s.inspect}: #{message}", code: "tag/unresolved")
      end

      def finding(severity, capability, clause, message, code)
        Finding.new(severity: severity, path: capability.relative_path, line: clause.line, column: 1,
                    message: message, code: code)
      end

      def sort(findings)
        findings.sort_by { |f| [ f.path, f.line, f.column, f.code ] }
      end
    end
  end
end
