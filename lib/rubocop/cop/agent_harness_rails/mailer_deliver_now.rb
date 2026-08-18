# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Prefer `deliver_later` from the request lifecycle so sending does not
      # block the user" — agent_harness_rails/rules/mailers.mdc. `deliver_now`
      # puts an SMTP round trip inside the request, and a mail server having a
      # slow morning becomes a slow page.
      #
      # Specs, previews, and rake tasks are excluded in config — those are
      # exactly the places `deliver_now` is correct.
      #
      # @example
      #   # bad
      #   UserMailer.with(user: @user).welcome.deliver_now
      #
      #   # good
      #   UserMailer.with(user: @user).welcome.deliver_later
      class MailerDeliverNow < Base
        extend AutoCorrector

        MSG = "Use `deliver_later` so sending does not block the request."
        RESTRICT_ON_SEND = %i[deliver_now].freeze

        def on_send(node)
          add_offense(node.loc.selector) do |corrector|
            corrector.replace(node.loc.selector, "deliver_later")
          end
        end
      end
    end
  end
end
