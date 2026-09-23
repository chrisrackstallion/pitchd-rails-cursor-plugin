# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Nest in the URL only while the parent scopes identity. Then stop" —
      # agent_harness_rails/rules/routes.mdc.
      #
      # One level of nesting earns its keep: the parent scopes the child's
      # identity. A second level produces `/projects/1/tasks/2/comments/3` and
      # path helpers nobody can guess. `shallow: true` is the escape hatch the
      # rule names, so a shallow nest is not reported.
      #
      # @example
      #   # bad
      #   resources :projects do
      #     resources :tasks do
      #       resources :comments
      #     end
      #   end
      #
      #   # good
      #   resources :projects do
      #     resources :tasks, shallow: true
      #   end
      class DeepNestedResources < Base
        MSG = "Nested %<depth>d deep. Use `shallow: true`, or split this into a top-level resource."
        RESOURCE_METHODS = %i[resources resource].freeze

        def on_block(node)
          return unless resource_block?(node)

          check(node, node.send_node)
        end
        alias on_numblock on_block

        # A leaf resource has no block of its own — `resources :comments` inside
        # two enclosing blocks is the third level, and is precisely the shape the
        # routes rule gives as its bad example.
        def on_send(node)
          return unless resource_call?(node)
          return if node.block_node

          check(node, node)
        end

        private

        def check(node, send_node)
          depth = nesting_depth(node)
          return if depth <= max_depth
          return if shallow?(node)

          add_offense(send_node.loc.selector, message: format(MSG, depth: depth))
        end

        def resource_call?(node)
          RESOURCE_METHODS.include?(node.method_name) && node.receiver.nil?
        end

        def resource_block?(node)
          node.block_type? && resource_call?(node.send_node)
        end

        # How many resource declarations enclose this one, counting itself. A
        # nest of one is the top-level `resources :projects do`.
        def nesting_depth(node)
          depth = 1
          node.each_ancestor(:block) { |ancestor| depth += 1 if resource_block?(ancestor) }
          depth
        end

        # `shallow: true` anywhere in the enclosing chain covers the nest below
        # it — that is what the option does.
        def shallow?(node)
          send_node = node.block_type? ? node.send_node : node
          return true if shallow_option?(send_node)

          node.each_ancestor(:block).any? { |ancestor| resource_block?(ancestor) && shallow_option?(ancestor.send_node) }
        end

        def shallow_option?(send_node)
          options = send_node.arguments.last
          return false unless options.respond_to?(:hash_type?) && options.hash_type?

          options.pairs.any? { |pair| pair.key.sym_type? && pair.key.value == :shallow && pair.value.true_type? }
        end

        def max_depth
          cop_config.fetch("Max", 2)
        end
      end
    end
  end
end
