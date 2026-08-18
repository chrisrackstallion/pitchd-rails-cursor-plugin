# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Generic `execute`, `run` method names on POROs and form objects →
      # domain verbs: `complete`, `process`, `import`" —
      # agent_harness_rails/rules/services.mdc, echoed in
      # agent_harness_rails/rules/naming.mdc.
      #
      # A PORO whose entry point is `call` is a service object that changed its
      # address. The name is the tell: `Account::Onboarding#complete` says what
      # happens, `Account::Onboarding#call` says only that something does.
      #
      # `perform` is exempt — it is the ActiveJob contract and must not be
      # renamed, as the rule says explicitly.
      #
      # @example
      #   # bad
      #   class Account::Onboarding
      #     def call(params) = ...
      #   end
      #
      #   # good
      #   class Account::Onboarding
      #     def complete(params) = ...
      #   end
      class GenericOperationMethod < Base
        MSG = "`%<name>s` says nothing about the domain. Name the verb: `complete`, `import`, `publish`."

        def on_def(node)
          name = node.method_name.to_s
          return unless forbidden?(name)

          add_offense(node.loc.name, message: format(MSG, name: name))
        end
        # `def self.call` is the classic service-object entry point, so the
        # class-method form matters as much as the instance form.
        alias on_defs on_def

        private

        def forbidden?(name)
          return false if cop_config.fetch("AllowedMethods", []).include?(name)

          cop_config.fetch("ForbiddenMethods", []).include?(name) ||
            (name.start_with?("do_") && name.length > 3)
        end
      end
    end
  end
end
