# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Never enqueue a job inside an open transaction — the job runs before
      # commit or after a rollback" — agent_harness_rails/rules/jobs.mdc, and the
      # same rule for mail in agent_harness_rails/rules/mailers.mdc.
      #
      # `after_create` and friends run inside the transaction. A worker can pick
      # the job up before the row is visible, or after the transaction rolled
      # back and the row never existed — a genuine race, and one that reproduces
      # only under load. The `_commit` variants fire after the transaction lands.
      #
      # Catches both shapes: the enqueue inline in a callback block, and the
      # callback that names a method which enqueues.
      #
      # @example
      #   # bad
      #   after_create { NotifySubscribersJob.perform_later(id) }
      #
      #   # bad
      #   after_save :notify_subscribers_later
      #
      #   def notify_subscribers_later
      #     NotifySubscribersJob.perform_later(id)
      #   end
      #
      #   # good
      #   after_create_commit :notify_subscribers_later
      class EnqueueOutsideCommit < Base
        MSG = "Enqueueing in `%<callback>s` runs inside the transaction — the job can run " \
              "before the commit, or after a rollback. Use `%<callback>s_commit`."

        # Only the callbacks with a direct `_commit` counterpart, so the message
        # can name a fix that exists. A `before_save` enqueue has the same
        # problem but no one-word answer, and is left to review.
        TRANSACTIONAL_CALLBACKS = %i[after_create after_save after_update after_destroy].freeze

        def_node_search :enqueues?, "(send _ {:perform_later :deliver_later} ...)"

        def on_class(node)
          @enqueueing_methods = nil
          body = node.body
          return if body.nil?

          each_callback(body) { |callback, send_node| check(callback, send_node, body) }
        end

        private

        def each_callback(body)
          nodes = body.begin_type? ? body.children : [ body ]

          nodes.each do |child|
            send_node = child.block_type? ? child.send_node : child
            next unless send_node.respond_to?(:method_name)
            next unless TRANSACTIONAL_CALLBACKS.include?(send_node.method_name)

            yield child, send_node
          end
        end

        def check(callback_node, send_node, class_body)
          name = send_node.method_name

          if callback_node.block_type?
            add_offense(callback_node.send_node.loc.selector, message: message_for(name)) if enqueues?(callback_node)
            return
          end

          return unless send_node.arguments.any? { |arg| arg.sym_type? && enqueueing_method?(arg.value, class_body) }

          add_offense(send_node.loc.selector, message: message_for(name))
        end

        # Resolves `after_save :notify` against the class's own method
        # definitions. A method defined elsewhere — in a concern, on a parent —
        # is out of reach, so this under-reports rather than guessing.
        def enqueueing_method?(name, class_body)
          enqueueing_methods(class_body).include?(name)
        end

        def enqueueing_methods(class_body)
          @enqueueing_methods ||= class_body.each_descendant(:def)
                                            .select { |definition| enqueues?(definition) }
                                            .map(&:method_name)
        end

        def message_for(callback)
          format(MSG, callback: callback)
        end
      end
    end
  end
end
