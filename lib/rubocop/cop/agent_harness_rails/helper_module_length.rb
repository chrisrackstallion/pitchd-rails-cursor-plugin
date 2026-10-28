# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Split by size, into a subdomain directory" —
      # agent_harness_rails/rules/views.mdc.
      #
      # Every helper module is included in every view, so its boundary exists
      # only for the reader, and a domain helper past the limit has stopped
      # being readable as one thing. The cop measures only modules named
      # `*Helper`, so a `module Billing` namespace wrapper is not counted against
      # the `InvoicesHelper` inside it. Kept apart from Metrics/ModuleLength so
      # the limit on helpers does not reset the app's limit on every module.
      #
      # @example
      #   # bad — app/helpers/billing_helper.rb, 140 lines across invoices and plans
      #   module BillingHelper
      #   end
      #
      #   # good — the invoice cluster moved into its subdomain
      #   # app/helpers/billing/invoices_helper.rb
      #   module Billing
      #     module InvoicesHelper
      #     end
      #   end
      class HelperModuleLength < Base
        include CodeLength

        MSG = "`%<name>s` has too many lines. [%<length>d/%<max>d] Move the cohesive cluster " \
              "into a subdomain helper under app/helpers/<domain>/."

        def on_module(node)
          @name = node.identifier.const_name
          return unless @name.end_with?("Helper")

          check_code_length(node)
        end

        private

        def message(length, max_length)
          format(MSG, name: @name, length: length, max: max_length)
        end
      end
    end
  end
end
