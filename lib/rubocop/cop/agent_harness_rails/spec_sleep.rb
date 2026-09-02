# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # `sleep` in a spec is a flake with a timer on it. It is either too short
      # on a loaded CI box, or too long on every run forever — usually both,
      # since the number gets raised each time it fails and never lowered.
      #
      # Capybara's finders already wait: `have_content`, `have_selector`, and
      # friends retry until the timeout. For non-Capybara waits, assert on the
      # state you are actually waiting for.
      #
      # @example
      #   # bad
      #   click_button "Publish"
      #   sleep 2
      #   expect(page).to have_content("Published")
      #
      #   # good — the matcher does the waiting
      #   click_button "Publish"
      #   expect(page).to have_content("Published")
      class SpecSleep < Base
        MSG = "Do not `sleep` in a spec. Capybara matchers already wait; otherwise assert " \
              "on the state you are waiting for."
        RESTRICT_ON_SEND = %i[sleep].freeze

        def on_send(node)
          return unless node.receiver.nil?

          add_offense(node)
        end
      end
    end
  end
end
