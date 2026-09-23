# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Every file under app/ has its spec at the mirrored path under spec/. A
      # spec whose subject lives somewhere else in app/ than the spec's path
      # implies is misfiled" — agent_harness_rails/rules/testing.mdc § Test
      # File Naming.
      #
      # RSpec/SpecFilePathFormat checks the described constant against the spec
      # filename; this checks it against where the constant is actually
      # defined, which is the half a filename cannot know. A concern is under
      # concerns/, a namespaced PORO is under its model's directory, and a spec
      # beside the wrong file splits one contract across two places.
      #
      # Runs only when the project index is on (rubocop-harness-index.yml).
      # Constants defined outside app/ are skipped, and so are controllers:
      # request specs describe them by constant from spec/requests/, and a
      # controller spec is what agent_harness_rails/rules/testing.mdc forbids.
      #
      # @example
      #   # bad — spec/models/account_onboarding_spec.rb, for a class defined
      #   # in app/models/account/onboarding.rb
      #   RSpec.describe Account::Onboarding do
      #
      #   # good — spec/models/account/onboarding_spec.rb
      #   RSpec.describe Account::Onboarding do
      class MisfiledSpec < Base
        include IndexHelp

        MSG = "`%<name>s` lives in %<source>s; its spec belongs at %<spec>s."
        RESTRICT_ON_SEND = %i[describe].freeze

        def on_send(node)
          return unless indexed?
          return unless top_level_group?(node)

          const = node.first_argument
          return unless const&.const_type?

          declaration = resolve_constant_in_index(const)
          return unless declaration.is_a?(Rubydex::Namespace)

          definition = primary_definition(declaration)
          return if definition.nil?

          source = definition.location.to_file_path
          return if source.include?("/app/controllers/")

          expected = mirrored_spec_path(source)
          return if same_file?(expected, processed_source.file_path)

          add_offense(const, message: format(MSG, name: declaration.name, source: app_relative(source), spec: app_relative(expected)))
        end

        private

        # The outermost example group: the `describe` whose own block has no
        # enclosing block.
        def top_level_group?(node)
          return false unless node.receiver.nil? || (node.receiver.const_type? && node.receiver.const_name == "RSpec")

          group = node.parent&.block_type? && node.parent.send_node.equal?(node) ? node.parent : node
          group.each_ancestor(:block).none?
        end

        # A class reopened in several files is filed under the one named for
        # it; otherwise the first definition under app/.
        def primary_definition(declaration)
          definitions = app_definitions(declaration)
          basename = "#{underscore(declaration.unqualified_name)}.rb"

          definitions.find { |definition| File.basename(definition.location.to_file_path) == basename } || definitions.first
        end

        def underscore(name)
          name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
        end
      end
    end
  end
end
