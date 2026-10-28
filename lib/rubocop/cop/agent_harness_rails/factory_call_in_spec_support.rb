# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # A method under spec/support/ that builds a record is a factory the
      # factory file cannot see. Nothing composes with it the way traits
      # compose, it drifts from the trait that means the same state, and the
      # example that calls it no longer shows the arrangement it depends on.
      # agent_harness_rails/rules/testing.mdc § Factories and Spec Support puts
      # records in factories and leaves support files to how a spec drives
      # the app: signing in, Current, driver configuration, matchers.
      #
      # @example
      #   # bad — spec/support/accounts.rb
      #   module AccountHelper
      #     def create_account_with_owner
      #       owner = create(:user)
      #       create(:account, owner: owner)
      #     end
      #   end
      #
      #   # good — spec/factories/accounts.rb
      #   factory :account do
      #     association :owner, factory: :user
      #   end
      #
      #   # good — spec/support/authentication.rb drives the app, builds nothing
      #   module AuthenticationHelper
      #     def sign_in(user)
      #       post session_path, params: { email_address: user.email_address, password: "password" }
      #     end
      #   end
      class FactoryCallInSpecSupport < Base
        MSG = "`%<method>s` builds a record in spec/support/. A record in a state is a factory " \
              "trait; an arrangement is inline in the example or private to its spec file. " \
              "Support files only drive the app."

        FACTORY_METHODS = %i[
          create create_list create_pair
          build build_list build_pair
          build_stubbed build_stubbed_list
          attributes_for attributes_for_list
        ].freeze
        RESTRICT_ON_SEND = FACTORY_METHODS

        def_node_matcher :factory_bot_receiver?, <<~PATTERN
          (const {nil? cbase} :FactoryBot)
        PATTERN

        def on_send(node)
          return unless node.receiver.nil? || factory_bot_receiver?(node.receiver)

          add_offense(node, message: format(MSG, method: node.method_name))
        end
      end
    end
  end
end
