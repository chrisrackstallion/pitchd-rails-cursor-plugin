# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # Checks the shape of the `intent:` metadata that binds a spec example to
      # an intent clause in docs/primitives/ —
      # agent_harness_rails/rules/primitives.mdc.
      #
      #   it "shows replies nested under their parent", intent: "comment_threads#I2"
      #
      # This cop only checks the form. Whether the clause exists, is still
      # active, and lists this spec file is `rails-evals`' job — it is the one
      # that can read the primitives tree. The split matters: a malformed tag is
      # a typo you fix while editing, and lint is where you are; an unresolvable
      # tag is a question about the doc, and belongs with the tool that reads it.
      #
      # @example
      #   # bad
      #   it "replies", intent: "comment_threads"        # no clause
      #   it "replies", intent: "comment_threads#2"      # missing the I
      #   it "replies", intent: :comment_threads         # not a string
      #
      #   # good
      #   it "replies", intent: "comment_threads#I2"
      #   describe "threading", intent: %w[comment_threads#I2 comment_threads#I3]
      class IntentTag < Base
        MSG = "Intent tags read `<capability>#I<n>`, naming a clause in " \
              "docs/primitives/capabilities/ — for example `comment_threads#I2`."
        FORMAT = /\A[a-z0-9_]+#I[1-9]\d*\z/

        def on_pair(node)
          return unless node.key.sym_type? && node.key.value == :intent

          Array(values(node.value)).each do |value|
            next if value.nil?

            add_offense(node.value, message: MSG) unless FORMAT.match?(value)
          end

          add_offense(node.value, message: MSG) if values(node.value).nil?
        end

        private

        # Returns the tag strings, or nil when the value is a shape a tag cannot
        # take. An interpolated or computed value returns [] — unreadable
        # statically, and not worth a false positive.
        def values(node)
          case node.type
          when :str then [ node.value ]
          when :array then node.values.map { |element| element.str_type? ? element.value : nil }.compact
          when :dstr, :send, :lvar, :ivar then []
          else nil
          end
        end
      end
    end
  end
end
