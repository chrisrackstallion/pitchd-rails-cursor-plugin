# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Every non-trivial mailer method should be previewable in development"
      # — agent_harness_rails/rules/mailers.mdc.
      #
      # Rails finds previews by name: `UserMailer` is previewed by
      # `UserMailerPreview`, method for method. The index knows whether that
      # class exists and what it defines, wherever the preview directory is
      # configured to be.
      #
      # Runs only when the project index is on (rubocop-harness-index.yml).
      # "Non-trivial" is a judgment the cop does not make; a mail that
      # genuinely needs no preview is a standing decision for the app's own
      # `Exclude:`.
      #
      # @example
      #   # bad — UserMailerPreview defines welcome but not receipt
      #   class UserMailer < ApplicationMailer
      #     def welcome; end
      #     def receipt; end
      #   end
      #
      #   # good
      #   class UserMailerPreview < ActionMailer::Preview
      #     def welcome; end
      #     def receipt; end
      #   end
      class MailerWithoutPreview < Base
        include IndexHelp
        include PublicMethods

        MSG_CLASS = "`%<mailer>s` has no `%<preview>s`. Every mail is previewable in development."
        MSG_METHOD = "`%<mailer>s#%<method>s` has no method on `%<preview>s`."

        def on_class(node)
          return unless indexed?
          return if node.each_ancestor(:class, :module).any?

          mails = public_defs(node.body)
          return if mails.empty?

          mailer = node.identifier.const_name
          preview_name = "#{mailer}Preview"
          preview = project_index[preview_name]
          return add_offense(node.identifier, message: format(MSG_CLASS, mailer: mailer, preview: preview_name)) if preview.nil?

          mails.reject { |mail| preview.find_member("#{mail.method_name}()") }.each do |mail|
            add_offense(mail.loc.name, message: format(MSG_METHOD, mailer: mailer, method: mail.method_name, preview: preview_name))
          end
        end
      end
    end
  end
end
