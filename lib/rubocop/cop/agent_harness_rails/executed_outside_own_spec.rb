# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Callers assert `have_enqueued_job`; the job's own spec calls
      # `perform_now`" and "callers assert `have_enqueued_mail`" —
      # agent_harness_rails/rules/testing.mdc § Ownership by Layer, and the
      # matching line in agent_harness_rails/rules/mailers.mdc.
      #
      # A model spec that runs the job it enqueues proves the job's work twice
      # and couples two files that should fail independently. The index says
      # which file defines the job or mailer, so the one spec allowed to run it
      # — the mirrored path under spec/ — is known rather than guessed from the
      # constant's name.
      #
      # Runs only when the project index is on (rubocop-harness-index.yml).
      # `described_class.perform_now` has no constant to resolve and is left
      # alone; so is anything defined outside app/.
      #
      # @example
      #   # bad — spec/models/article_spec.rb
      #   NotifySubscribersJob.perform_now(article.id)
      #
      #   # good — spec/models/article_spec.rb
      #   expect { article.publish }.to have_enqueued_job(NotifySubscribersJob)
      #
      #   # good — spec/jobs/notify_subscribers_job_spec.rb
      #   described_class.perform_now(article.id)
      class ExecutedOutsideOwnSpec < Base
        include IndexHelp

        MSG = "`%<name>s` runs for real only in %<spec>s. Here, assert `%<matcher>s`."
        RESTRICT_ON_SEND = %i[perform_now deliver_now deliver_now!].freeze
        MATCHERS = { perform_now: "have_enqueued_job", deliver_now: "have_enqueued_mail",
                     "deliver_now!": "have_enqueued_mail" }.freeze

        def on_send(node)
          return unless indexed?

          root = root_constant(node.receiver)
          return if root.nil?

          declaration = resolve_constant_in_index(root)
          return unless declaration.is_a?(Rubydex::Class)

          definition = app_definitions(declaration).first
          return if definition.nil?

          own_spec = mirrored_spec_path(definition.location.to_file_path)
          return if same_file?(own_spec, processed_source.file_path)

          add_offense(node.loc.selector, message: format(MSG, name: declaration.name, spec: app_relative(own_spec),
                                                              matcher: MATCHERS.fetch(node.method_name)))
        end

        private

        # `UserMailer.with(user:).welcome.deliver_now` bottoms out at the
        # constant; `described_class.perform_now` bottoms out at a bare call.
        def root_constant(node)
          node = node.receiver while node&.send_type? && node.receiver
          node if node&.const_type?
        end
      end
    end
  end
end
