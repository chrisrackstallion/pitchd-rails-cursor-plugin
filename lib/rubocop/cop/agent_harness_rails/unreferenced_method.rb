# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # A method nothing calls is kept "just in case", and the answer is the
      # same as for commented-out code — agent_harness_rails/rules/comments.mdc:
      # delete it, git remembers.
      #
      # Lint/UnusedPrivateMethod covers private methods and knows nothing about
      # Rails. This one looks at every method in the directories it is scoped
      # to and counts three kinds of use, project-wide: a call by that name
      # anywhere in the index; the name as a symbol or inside a string literal
      # in any indexed file, which is how callbacks, `delegate`, validations and
      # `send` name their targets; and the name as a token in any view template,
      # which is where model presentation methods and helpers are actually
      # called from.
      #
      # What remains invisible is dispatch assembled from strings
      # (`send("#{kind}_summary")`) and templates outside `TemplateGlobs`, so the
      # cop ships disabled and is run as a sweep:
      #
      #   bin/rubocop --only AgentHarnessRails/UnreferencedMethod
      #
      # Names Rails calls by convention are exempt through `AllowedMethods` and
      # `AllowedPatterns`; a policy's public predicates are exempt because
      # Pundit dispatches to them by name; an override of an inherited method
      # is exempt because renaming it breaks the contract. Runs only when the
      # project index is on (rubocop-harness-index.yml).
      #
      # @example
      #   # bad — nothing in app/, spec/, or app/views/ mentions `legacy_slug`
      #   class Article < ApplicationRecord
      #     def legacy_slug = title.parameterize
      #   end
      class UnreferencedMethod < Base
        include IndexHelp

        MSG = "Nothing in the project calls `%<method>s` — no call, symbol, or template mentions it. " \
              "Delete it, or name the caller RuboCop cannot see in `AllowedMethods`."

        IDENTIFIER = /[a-zA-Z_]\w*[?!]?/
        SYMBOL = /(?<![\w:]):([a-zA-Z_]\w*[?!=]?)/
        PERCENT_SYMBOLS = /%[iIwW][\[({<]([^\])}>]*)[\])}>]/m
        STRING = /"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'/m

        def on_def(node)
          return unless indexed?
          return if skip?(node)

          name = node.method_name.to_s
          return if referenced?(name)

          add_offense(node.loc.name, message: format(MSG, method: name))
        end
        alias on_defs on_def

        private

        def skip?(node)
          name = node.method_name.to_s
          return true if allowed?(name)
          return true if node.each_ancestor(:any_def, :any_block, :sclass).any?

          namespace_node = node.each_ancestor(:class, :module).first
          return true if namespace_node.nil?
          return true if policy_predicate?(name, namespace_node)

          override?(node, namespace_node)
        end

        def allowed?(name)
          cop_config.fetch("AllowedMethods", []).include?(name) ||
            cop_config.fetch("AllowedPatterns", []).any? { |pattern| Regexp.new(pattern).match?(name) }
        end

        def policy_predicate?(name, namespace_node)
          name.end_with?("?") && namespace_node.identifier.const_name.end_with?("Policy")
        end

        def override?(node, namespace_node)
          declaration = resolve_constant_in_index(namespace_node.identifier)
          return false unless declaration.is_a?(Rubydex::Namespace)

          scope = node.defs_type? ? indexed_singleton_of(declaration) : declaration
          !scope.nil? && inherited_index_member?(scope, "#{node.method_name}()")
        end

        def referenced?(name)
          call_names.include?(name) || literal_names.include?(name) || template_names.include?(name)
        end

        def call_names
          index_memo(:call_names) do
            project_index.method_references.to_set { |reference| reference.name.delete_suffix("()") }
          end
        end

        # Symbols, `%i[]` lists and identifiers inside strings, across every
        # indexed file.
        def literal_names
          index_memo(:literal_names) do
            indexed_sources.each_with_object(Set.new) do |source, names|
              source.scan(SYMBOL) { names << Regexp.last_match(1) }
              source.scan(PERCENT_SYMBOLS) { Regexp.last_match(1).scan(IDENTIFIER) { |token| names << token } }
              source.scan(STRING) { Regexp.last_match.captures.compact.first.scan(IDENTIFIER) { |token| names << token } }
            end
          end
        end

        def template_names
          index_memo(:template_names) do
            root = config.base_dir_for_path_parameters
            cop_config.fetch("TemplateGlobs", []).flat_map { |glob| Dir.glob(glob, base: root) }.uniq
                      .each_with_object(Set.new) do |match, names|
              File.read(File.expand_path(match, root), encoding: "UTF-8").scan(IDENTIFIER) { |token| names << token }
            end
          end
        end

        def indexed_sources
          project_index.documents.filter_map do |document|
            next unless document.uri.start_with?(FILE_URI_PREFIX)

            path = document.uri.delete_prefix(FILE_URI_PREFIX).sub(WINDOWS_DRIVE_PREFIX, "")
            File.read(path, encoding: "UTF-8") if File.file?(path)
          end
        end
      end
    end
  end
end
