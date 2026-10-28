# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Policies only see `user` and `record`" —
      # agent_harness_rails/rules/policies.mdc.
      #
      # A policy that reaches for `params`, `request`, or `session` has stopped
      # being a plain object answering "may this user do this?" and started
      # depending on the request that happened to call it — which is what makes
      # policy specs able to test the full role x action matrix without a
      # controller. Pass what the policy needs through `record`.
      #
      # @example
      #   # bad
      #   def update?
      #     user.admin? || params[:token] == record.share_token
      #   end
      #
      #   # good — the controller resolves the request, the policy judges it
      #   def update?
      #     user.admin? || record.shared_with?(user)
      #   end
      class PolicyContext < Base
        MSG = "A policy sees only `user` and `record`; `%<name>s` belongs to the controller."
        RESTRICT_ON_SEND = %i[params request session cookies].freeze

        def on_send(node)
          return unless node.receiver.nil?
          return unless node.arguments.empty?

          add_offense(node, message: format(MSG, name: node.method_name))
        end
      end
    end
  end
end
