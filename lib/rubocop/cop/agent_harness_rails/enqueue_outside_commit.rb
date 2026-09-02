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
      # Catches the enqueue inline in a callback block, and the callback that
      # names a method which enqueues — in the same file always, and through
      # concerns and parents when the project index is on
      # (rubocop-harness-index.yml): a model's callback resolved to the method a
      # concern defines, and a concern's `included do` callback resolved to the
      # method each includer defines.
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
        include IndexHelp

        MSG = "Enqueueing in `%<callback>s` runs inside the transaction — the job can run " \
              "before the commit, or after a rollback. Use `%<callback>s_commit`."

        # Only the callbacks with a direct `_commit` counterpart, so the message
        # can name a fix that exists. A `before_save` enqueue has the same
        # problem but no one-word answer, and is left to review.
        TRANSACTIONAL_CALLBACKS = %i[after_create after_save after_update after_destroy].freeze
        ENQUEUE_METHODS = %w[perform_later perform_all_later deliver_later deliver_later!].freeze

        def_node_search :enqueues?, "(send _ {:perform_later :perform_all_later :deliver_later :deliver_later!} ...)"

        def on_class(node)
          scan(node, node.body)
        end

        # A concern declares its callbacks inside `included do`; the method they
        # name may be the concern's own or each includer's.
        def on_module(node)
          return if node.body.nil?

          included_blocks(node.body).each { |block| scan(node, block.body) }
        end

        private

        def scan(scope_node, body)
          return if body.nil?

          each_callback(body) { |callback, send_node| check(callback, send_node, scope_node) }
        end

        def included_blocks(body)
          nodes = body.begin_type? ? body.children : [ body ]
          nodes.select { |child| child.block_type? && child.send_node.receiver.nil? && child.send_node.method?(:included) }
        end

        def each_callback(body)
          nodes = body.begin_type? ? body.children : [ body ]

          nodes.each do |child|
            send_node = child.block_type? ? child.send_node : child
            next unless send_node.respond_to?(:method_name)
            next unless TRANSACTIONAL_CALLBACKS.include?(send_node.method_name)

            yield child, send_node
          end
        end

        def check(callback_node, send_node, scope_node)
          name = send_node.method_name

          if callback_node.block_type?
            add_offense(callback_node.send_node.loc.selector, message: message_for(name)) if enqueues?(callback_node)
            return
          end

          return unless send_node.arguments.any? { |arg| arg.sym_type? && enqueueing_method?(arg.value, scope_node) }

          add_offense(send_node.loc.selector, message: message_for(name))
        end

        def enqueueing_method?(name, scope_node)
          local_enqueueing_methods(scope_node).include?(name) || indexed_enqueueing_method?(name, scope_node)
        end

        def local_enqueueing_methods(scope_node)
          @local_enqueueing_methods ||= {}.compare_by_identity
          @local_enqueueing_methods[scope_node] ||= scope_node.body.each_descendant(:def)
                                                             .select { |definition| enqueues?(definition) }
                                                             .map(&:method_name)
        end

        # The method as the index knows it: on the class or anything it inherits
        # from, or — for a concern — on the concern itself or any includer.
        # Without the index a method defined elsewhere is out of reach, and the
        # cop under-reports rather than guesses.
        def indexed_enqueueing_method?(name, scope_node)
          return false unless indexed?

          declaration = resolve_constant_in_index(scope_node.identifier)
          return false unless declaration.is_a?(Rubydex::Namespace)

          holders = [ declaration ]
          holders += declaration.descendants.to_a if scope_node.module_type?

          holders.any? do |holder|
            method = holder.find_member("#{name}()")
            method && calls_within?(method, ENQUEUE_METHODS)
          end
        end

        def message_for(callback)
          format(MSG, callback: callback)
        end
      end
    end
  end
end
