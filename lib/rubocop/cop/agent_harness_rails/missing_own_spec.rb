# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Concerns with behaviour always get their own spec file" —
      # agent_harness_rails/rules/testing.mdc — and "Policy spec exists with
      # tests for each role × action" — agent_harness_rails/rules/policies.mdc.
      #
      # Both are stated without exception, and both are existence claims the
      # index can settle: is the constant referenced from any file under the
      # spec directory that mirrors where it lives? `RSpec.describe Publishable`
      # in spec/models/concerns/ is such a reference; a model spec that happens
      # to mention the concern is not, and does not count.
      #
      # Runs only when the project index is on (rubocop-harness-index.yml). A
      # concern with no instance methods — associations and scopes only — has no
      # behaviour to specify and is not reported. Whether the spec that exists
      # covers the full matrix is judgment, and stays with review.
      #
      # @example
      #   # bad — app/models/concerns/publishable.rb, and nothing under
      #   # spec/models/concerns/ describes it
      #   module Publishable
      #     def publish(by:) = create_publication!(publisher: by)
      #   end
      #
      #   # good — spec/models/concerns/publishable_spec.rb
      #   RSpec.describe Publishable do
      class MissingOwnSpec < Base
        include IndexHelp

        MSG = "`%<name>s` has no spec under %<dir>s/. %<why>s"
        WHY_CONCERN = "A concern with behaviour gets its own spec file — the single home for its contract."
        WHY_POLICY = "Every policy gets a spec covering each role × action."
        WHY_DEFAULT = "The spec tree mirrors app/; this is where its contract lives."

        def on_class(node)
          check(node)
        end

        def on_module(node)
          check(node) if behaviour?(node)
        end

        private

        def check(node)
          return unless indexed?
          return if node.each_ancestor(:class, :module).any?

          declaration = resolve_constant_in_index(node.identifier)
          return if declaration.nil?

          spec_dir = mirrored_spec_dir(processed_source.file_path)
          return if spec_dir.nil? || referenced_under?(declaration, spec_dir)

          add_offense(node.identifier,
                      message: format(MSG, name: declaration.name, dir: app_relative(spec_dir), why: why_for(spec_dir)))
        end

        def referenced_under?(declaration, spec_dir)
          prefix = "#{spec_dir}/"
          referencing_files[declaration.name].any? { |path| path.start_with?(prefix) }
        end

        def behaviour?(node)
          node.body && node.body.each_node(:def).any?
        end

        def why_for(spec_dir)
          if spec_dir.end_with?("/concerns") then WHY_CONCERN
          elsif spec_dir.end_with?("/policies") then WHY_POLICY
          else WHY_DEFAULT
          end
        end
      end
    end
  end
end
