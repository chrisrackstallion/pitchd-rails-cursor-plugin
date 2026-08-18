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

        findings += nested_docs(capabilities_dir, root: root)
        findings += capabilities.flat_map(&:findings)
        findings += check_evaluations(capabilities, tags, root: root)
        findings += check_tags(capabilities, tags)

        Result.new(findings: sort(findings), capabilities: capabilities.size,
                   clauses: capabilities.sum { |c| c.clauses.size })
      end

      private

      # A capability doc in a subdirectory is invisible to `Capability.load_all`,
      # which globs one level deep — and an `intent:` tag names a bare filename
      # with no path in it, so nesting could not be addressed even if it were
      # loaded. Reported rather than swept up: the failure it replaces is a doc
      # whose clauses simply do not exist as far as this tool is concerned, with
      # a green run over the top.
      def nested_docs(dir, root:)
        Dir.glob(File.join(dir, "**", "*.md")).sort
           .reject { |path| File.dirname(path) == dir }
           .map do |path|
             Finding.new(severity: :error, path: path.delete_prefix("#{root}/"), line: 1, column: 1,
                         message: "capability docs live directly in #{CAPABILITIES_SUBDIR}/ — group with a "                                   "name prefix instead (billing/plans.md becomes billing_plans.md), "                                   "because an `intent:` tag names a filename with no path in it",
                         code: "doc/nested")
           end
      end

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

      # Every active clause on a built doc names a spec. The one non-failing case
      # is a doc mid-amendment: the plan has landed and the code has not, so the
      # gap is the branch's, not the capability's, and close-out closes it.
      def coverage(capability, clause)
        return [] unless capability.built?
        return [] unless clause.evaluations.empty?

        if capability.in_flight?
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
