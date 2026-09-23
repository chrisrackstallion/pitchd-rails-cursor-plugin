# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "There is no service layer" — agent_harness_rails/rules/services.mdc.
      # Business logic belongs on the model; multi-step work on one aggregate
      # belongs in a PORO namespaced under it; async work belongs in a job.
      #
      # Flags a class living under app/services/, or named with a suffix that
      # signals a wrapper around behaviour that belongs elsewhere.
      #
      # Scoped to service *objects*, not to the words they use. A suffix only
      # marks a wrapper when the name puts something in front of it — a bare
      # `Service` or `Command` is domain vocabulary, and a class with a table
      # behind it is named for what it stores rather than what it wraps.
      #
      # @example
      #   # bad
      #   class PublishArticleService
      #     def call(article) = article.update!(published: true)
      #   end
      #
      #   # good — a domain verb on the model
      #   class Article < ApplicationRecord
      #     def publish(by: Current.user) = create_publication!(publisher: by)
      #   end
      #
      #   # good — a PORO namespaced under the aggregate it serves
      #   class Account::Onboarding
      #     def complete(params) = ...
      #   end
      #
      #   # good — the domain really does have services in it
      #   class Service < ApplicationRecord
      #     belongs_to :account
      #   end
      class ServiceObject < Base
        include IndexHelp

        MSG_SUFFIX = "Avoid `%<name>s`. Put the behaviour on the model, in a PORO " \
                     "namespaced under it, or in a job."
        MSG_DIRECTORY = "Avoid app/services/. Put the behaviour on the model, in a PORO " \
                        "namespaced under it, or in a job."

        RECORD_SUPERCLASSES = %w[ApplicationRecord ActiveRecord::Base].freeze

        # Macros that only appear on something with a table (or an association)
        # behind it. Deliberately not `validates` or `scope`: an ActiveModel form
        # object has both, and a form object called `CheckoutOperation` is the
        # wrapper this cop exists to find.
        RECORD_MACROS = %i[
          belongs_to has_many has_one has_and_belongs_to_many
          enum normalizes encrypts table_name=
        ].freeze

        def on_class(node)
          return add_offense(node.identifier, message: MSG_DIRECTORY) if in_services_directory?

          name = node.identifier.short_name.to_s
          return unless wrapper_suffix?(name)
          return if record?(node)

          add_offense(node.identifier, message: format(MSG_SUFFIX, name: name))
        end

        private

        def in_services_directory?
          processed_source.path.to_s.include?("app/services/")
        end

        # A namespaced PORO is the sanctioned home for multi-step work, so
        # `Article::Publisher` passes while `ArticlePublisherService` does not —
        # the suffix is what marks the wrapper, not the nesting.
        #
        # `name != suffix` is what keeps a domain noun out of it. A billing app's
        # `Service`, a CQRS-free app's `Command`: the word is the whole name, so
        # there is no wrapped verb for the suffix to be a suffix of.
        def wrapper_suffix?(name)
          suffixes.any? { |suffix| name != suffix && name.end_with?(suffix) }
        end

        def suffixes
          cop_config.fetch("Suffixes", [])
        end

        # Something with a table behind it is out of scope however it is spelled.
        # `class PaymentService < ApplicationRecord` is a row, and the rule has
        # nothing to say about rows — moving behaviour onto the model is the
        # advice, and this class already *is* the model.
        def record?(node)
          record_superclass?(node.parent_class) || record_macros?(node.body) || indexed_record?(node)
        end

        # With the project index the ancestry is known rather than read off the
        # superclass's spelling, so a record reached through any depth of
        # inheritance passes.
        def indexed_record?(node)
          return false unless indexed?

          declaration = resolve_constant_in_index(node.identifier)
          declaration.is_a?(Rubydex::Class) &&
            declaration.ancestors.any? { |ancestor| RECORD_SUPERCLASSES.include?(ancestor.name) }
        end

        def record_superclass?(superclass)
          return false unless superclass.respond_to?(:const_type?) && superclass.const_type?

          name = superclass.source
          return true if RECORD_SUPERCLASSES.include?(name)

          # STI: `class PaymentService < Service` inherits a table from a parent
          # whose own bare name this cop already accepts as domain vocabulary.
          suffixes.include?(superclass.short_name.to_s)
        end

        def record_macros?(body)
          return false if body.nil?

          nodes = body.begin_type? ? body.children : [ body ]
          nodes.any? do |child|
            child.respond_to?(:send_type?) && child.send_type? && RECORD_MACROS.include?(child.method_name)
          end
        end
      end
    end
  end
end
