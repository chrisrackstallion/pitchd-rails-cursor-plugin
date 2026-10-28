# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # Turning off CSRF verification is a security decision, not a convenience.
      # agent_harness_rails/rules/controllers.mdc keeps authentication opt-outs
      # explicit and narrow; this one disables forgery protection for every
      # action it covers.
      #
      # Genuine cases exist — a webhook endpoint verified by signature instead.
      # Those are a standing, human-owned decision, so they belong in an
      # `Exclude:` your team writes and signs off, not in a passing lint run
      # nobody looked at.
      #
      # @example
      #   # bad
      #   skip_before_action :verify_authenticity_token
      #
      #   # good — for a signed webhook, scoped and paired with real verification
      #   class WebhooksController < ActionController::Base
      #     before_action :verify_signature
      #   end
      class CsrfSkip < Base
        MSG = "Do not skip CSRF verification. If a signed endpoint genuinely needs it, " \
              "exclude that file in .rubocop.yml as a deliberate, reviewed decision."
        RESTRICT_ON_SEND = %i[skip_before_action skip_forgery_protection].freeze

        def_node_matcher :skips_csrf?, <<~PATTERN
          (send nil? {:skip_before_action :skip_forgery_protection} <(sym :verify_authenticity_token) ...>)
        PATTERN

        def on_send(node)
          return unless node.method?(:skip_forgery_protection) || skips_csrf?(node)

          add_offense(node)
        end
      end
    end
  end
end
