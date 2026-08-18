# frozen_string_literal: true

module AgentHarnessRails
  module Evals
    # One offence. Shaped like a RuboCop offence so the text formatter can print
    # `path:line:column: S: message [code]` and the JSON formatter can dump the
    # same fields without a second representation.
    #
    # `code` is a stable `category/detail` slug (e.g. `clause/unproven`) — the
    # thing a reader greps for and a CI log gets filtered on. Messages may be
    # reworded; codes are the contract.
    Finding = Struct.new(:severity, :path, :line, :column, :message, :code, keyword_init: true) do
      SEVERITY_LETTERS = { error: "E", warning: "W" }.freeze

      def error? = severity == :error

      def letter = SEVERITY_LETTERS.fetch(severity)

      def to_s
        "#{path}:#{line}:#{column}: #{letter}: #{message} [#{code}]"
      end

      def to_h
        { severity: severity, path: path, line: line, column: column, message: message, code: code }
      end
    end
  end
end
