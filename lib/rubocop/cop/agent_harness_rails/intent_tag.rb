# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # Checks the shape and the placement of the `intent:` metadata that binds a
      # spec example to an intent clause in docs/primitives/ —
      # agent_harness_rails/rules/primitives.mdc.
      #
      #   it "shows replies nested under their parent", intent: "comment_threads#I2"
      #
      # The tag belongs on the example, never on the `describe` or `context`
      # around it. A group tag reads as a shortcut — one line covering four
      # examples — but it survives the deletion of the very example it was
      # standing for: the siblings keep the group green, and the clause goes on
      # claiming proof that no longer exists. Tagging each proving example costs
      # a repeated line and buys the loud break the design is for.
      #
      # This cop only checks form and placement. Whether the clause exists, is
      # still active, and lists this spec file is `agent_harness_rails evals`'
      # job — it is the one that can read the primitives tree. The split
      # matters: a misplaced or malformed tag is something you fix while
      # editing, and lint is where you are; an unresolvable tag is a question
      # about the doc, and belongs with the tool that reads it.
      #
      # @example
      #   # bad
      #   it "replies", intent: "comment_threads"        # no clause
      #   it "replies", intent: "comment_threads#2"      # missing the I
      #   it "replies", intent: :comment_threads         # not a string
      #   describe "threading", intent: "comment_threads#I2"   # on a group
      #
      #   # good
      #   it "replies", intent: "comment_threads#I2"
      #   it "nests three deep", intent: %w[comment_threads#I2 comment_threads#I3]
      class IntentTag < Base
        MSG = "Intent tags read `<capability>#I<n>`, naming a clause in " \
              "docs/primitives/capabilities/ — for example `comment_threads#I2`."
        MSG_PLACEMENT = "Tag the example that proves the clause, not `%<method>s` — a group tag " \
                        "keeps resolving after the example it stood for is deleted."
        FORMAT = /\A[a-z0-9_]+#I[1-9]\d*\z/
        EXAMPLE_METHODS = %i[it specify example scenario its].freeze

        def on_pair(node)
          return unless node.key.sym_type? && node.key.value == :intent

          tags = values(node.value)
          return add_offense(node.value, message: MSG) if tags.nil?

          tags.each { |value| add_offense(node.value, message: MSG) unless FORMAT.match?(value) }
          check_placement(node) unless tags.empty?
        end

        private

        # Returns the tag strings, or nil when the value is a shape a tag cannot
        # take. An interpolated or computed value returns [] — unreadable
        # statically, and not worth a false positive. That empty case also keeps
        # the placement check off an ordinary `intent:` argument in app code that
        # happens to sit inside a spec.
        def values(node)
          case node.type
          when :str then [ node.value ]
          when :array then node.values.map { |element| element.str_type? ? element.value : nil }.compact
          when :dstr, :send, :lvar, :ivar then []
          else nil
          end
        end

        def check_placement(node)
          call = metadata_call(node)
          return if call.nil?
          return if call.receiver.nil? && EXAMPLE_METHODS.include?(call.method_name)

          add_offense(call.loc.selector, message: format(MSG_PLACEMENT, method: call.method_name))
        end

        # The call this pair is trailing metadata for. A braced hash is a literal
        # somewhere in the body — a `let`, a factory attribute list — not
        # metadata, so it is left alone.
        def metadata_call(node)
          hash = node.parent
          return nil unless hash&.hash_type? && !hash.braces?

          call = hash.parent
          call if call&.send_type?
        end
      end
    end
  end
end
