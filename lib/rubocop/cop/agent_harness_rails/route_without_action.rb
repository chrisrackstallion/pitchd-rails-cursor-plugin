# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "`only` / `except` match real controller actions" —
      # agent_harness_rails/rules/routes.mdc — and the nesting pitfall
      # agent_harness_rails/rules/controllers.mdc spells out: a `resource`
      # nested without `module:` routes to a top-level controller that does not
      # exist.
      #
      # Both are runtime failures RuboCop could not see from routes.rb alone.
      # With the project index it resolves the controller the way Rails will —
      # `namespace`, `scope module:`, and `controller:` included — and checks
      # each routed action against the class and its ancestors, so an action
      # inherited from a base controller passes.
      #
      # Runs only when the project index is on (rubocop-harness-index.yml). A
      # controller whose ancestry includes an unresolved mixin is skipped: a
      # concern from a gem could be supplying the actions.
      #
      # @example
      #   # bad — Cards::ClosuresController exists; ClosuresController does not
      #   resources :cards do
      #     resource :closure
      #   end
      #
      #   # good
      #   resources :cards do
      #     scope module: :cards do
      #       resource :closure
      #     end
      #   end
      #
      #   # bad — ArticlesController defines index and show only
      #   resources :articles, only: %i[ index show edit ]
      #
      #   # good
      #   resources :articles, only: %i[ index show ]
      class RouteWithoutAction < Base
        include IndexHelp

        MSG_CONTROLLER = "`%<controller>s` is not defined, so every route here 404s.%<hint>s"
        MSG_ACTION = "`%<controller>s#%<action>s` is not defined. Trim the route with `only:` / `except:`, " \
                     "or define the action."
        HINT = " `%<candidate>s` is — route it inside `scope module: %<module>s`."

        RESTRICT_ON_SEND = %i[resources resource].freeze
        RESOURCES_ACTIONS = %i[index show new create edit update destroy].freeze
        RESOURCE_ACTIONS = %i[show new create edit update destroy].freeze
        SCOPING_METHODS = %i[namespace scope resources resource].freeze

        def on_send(node)
          return unless indexed?
          return unless node.receiver.nil? && node.first_argument&.sym_type?

          controller = controller_name(node)
          return if controller.nil?

          declaration = lookup(controller)
          return add_offense(node.first_argument, message: controller_message(controller)) if declaration.nil?
          return unless declaration.is_a?(Rubydex::Class) && mixins_resolved?(declaration)

          check_actions(node, declaration)
        end

        private

        def check_actions(node, declaration)
          actions = routed_actions(node)
          return if actions.nil?

          actions.reject { |action| declaration.find_member("#{action}()") }.each do |action|
            add_offense(anchor_for(node, action),
                        message: format(MSG_ACTION, controller: declaration.name, action: action))
          end
        end

        # The constant Rails will look up: enclosing namespaces and modules,
        # then this call's own `module:` and `controller:` options, then the
        # pluralised, camelised resource name.
        def controller_name(node)
          base = controller_option(node) || base_name(node)
          return nil if base.nil?

          segments = enclosing_modules(node)
          segments << literal(option(node, :module)) if option(node, :module)
          return nil if segments.include?(nil)

          (segments + [ base ]).map { |segment| camelize(segment) }.join("::")
        end

        # `controller: "reports"` names the controller relative to the current
        # module, like a resource name would.
        def controller_option(node)
          value = option(node, :controller)
          return nil if value.nil?

          name = literal(value)
          name && "#{name}_controller"
        end

        def base_name(node)
          name = node.first_argument.value.to_s
          return "#{name}_controller" if node.method?(:resources)

          plural = pluralize(name)
          plural && "#{plural}_controller"
        end

        # Outermost first. A nested `resources` block does not change the
        # module unless it says `module:`; `namespace` always does.
        def enclosing_modules(node)
          node.each_ancestor(:block).filter_map do |block|
            send_node = block.send_node
            next unless send_node.receiver.nil? && SCOPING_METHODS.include?(send_node.method_name)

            if option(send_node, :module)
              literal(option(send_node, :module))
            elsif send_node.method?(:namespace)
              literal(send_node.first_argument)
            end
          end.reverse
        end

        def option(send_node, key)
          options = send_node.arguments.last
          return nil unless options.respond_to?(:hash_type?) && options.hash_type?

          options.pairs.find { |pair| pair.key.sym_type? && pair.key.value == key }&.value
        end

        # A symbol or string, or nil when the value is computed and the route
        # cannot be read statically.
        def literal(node)
          return nil unless node.respond_to?(:type)

          case node.type
          when :sym, :str then node.value.to_s
          end
        end

        def routed_actions(node)
          defaults = node.method?(:resources) ? RESOURCES_ACTIONS : RESOURCE_ACTIONS
          only = option(node, :only)
          except = option(node, :except)

          if only
            list = action_list(only)
            list && (list & defaults)
          elsif except
            list = action_list(except)
            list && (defaults - list)
          else
            defaults
          end
        end

        def action_list(node)
          nodes = node.array_type? ? node.values : [ node ]
          return nil unless nodes.all?(&:sym_type?)

          nodes.map(&:value)
        end

        def anchor_for(node, action)
          only = option(node, :only)
          return node.first_argument unless only

          (only.array_type? ? only.values : [ only ]).find { |value| value.value == action } || node.first_argument
        end

        # Exact name first; then a case-insensitive match, because an
        # `inflect.acronym` the cop cannot see spells `Api` as `API`.
        def lookup(controller)
          project_index[controller] ||
            candidates(controller).find { |declaration| declaration.name.casecmp?(controller) }
        end

        def candidates(controller)
          short = controller.split("::").last
          project_index.search(short).select do |declaration|
            declaration.is_a?(Rubydex::Class) && declaration.unqualified_name == short
          end
        end

        def controller_message(controller)
          candidate = candidates(controller).first
          hint = ""
          if candidate
            namespace = candidate.name.split("::")[0...-1]
            hint = format(HINT, candidate: candidate.name, module: namespace.map { |part| underscore(part) }.join("/").then { |m| namespace.one? ? ":#{m}" : "\"#{m}\"" })
          end

          format(MSG_CONTROLLER, controller: controller, hint: hint)
        end

        # Instance-side mixins only: `extend` cannot add actions, and every
        # controller's superclass chain ends in an unindexed ActionController::Base.
        def mixins_resolved?(declaration)
          declaration.ancestors.all? do |ancestor|
            ancestor.definitions.all? { |definition| resolved_mixin_references?(definition, ignore_extend: true) }
          end
        end

        def camelize(segment)
          segment.to_s.split("/").map { |part| part.split("_").map(&:capitalize).join }.join("::")
        end

        def underscore(name)
          name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
        end

        # Rails pluralises through ActiveSupport, which rubocop-rails brings
        # along. Without it a singular `resource` is skipped rather than guessed.
        def pluralize(name)
          require "active_support/inflector" unless defined?(ActiveSupport::Inflector)
          ActiveSupport::Inflector.pluralize(name)
        rescue LoadError
          nil
        end
      end
    end
  end
end
