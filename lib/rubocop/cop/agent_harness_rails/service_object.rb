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
      class ServiceObject < Base
        MSG_SUFFIX = "Avoid `%<name>s`. Put the behaviour on the model, in a PORO " \
                     "namespaced under it, or in a job."
        MSG_DIRECTORY = "Avoid app/services/. Put the behaviour on the model, in a PORO " \
                        "namespaced under it, or in a job."

        def on_class(node)
          return add_offense(node.identifier, message: MSG_DIRECTORY) if in_services_directory?

          name = node.identifier.short_name.to_s
          return unless forbidden_suffix?(name)

          add_offense(node.identifier, message: format(MSG_SUFFIX, name: name))
        end

        private

        def in_services_directory?
          processed_source.path.to_s.include?("app/services/")
        end

        # A namespaced PORO is the sanctioned home for multi-step work, so
        # `Article::Publisher` passes while `ArticlePublisherService` does not —
        # the suffix is what marks the wrapper, not the nesting.
        def forbidden_suffix?(name)
          cop_config.fetch("Suffixes", []).any? { |suffix| name.end_with?(suffix) }
        end
      end
    end
  end
end
