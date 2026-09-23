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
    #
    # `:notice` is `guard`'s only severity and never an offence: it reports what
    # a change did to intent and its proof, for a person to judge.
    #
    # `details` carries what does not belong on the headline: labelled lines
    # (was/now clause text) and unlabelled guidance. The text renderer truncates
    # labelled text; `to_h` keeps it whole, so JSON is the full record.
    Finding = Struct.new(:severity, :path, :line, :column, :message, :code, :details,
                         keyword_init: true) do
      SEVERITY_LETTERS = { error: "E", warning: "W", notice: "N" }.freeze

      def error? = severity == :error

      def letter = SEVERITY_LETTERS.fetch(severity)

      def to_s
        "#{path}:#{line}:#{column}: #{letter}: #{message} [#{code}]"
      end

      def to_h
        base = { severity: severity, path: path, line: line, column: column, message: message, code: code }
        details.nil? || details.empty? ? base : base.merge(details: details.map(&:to_h))
      end
    end

    # Assigned onto the class rather than inside its block: a constant assigned
    # in the block would land on the lexically enclosing module, not on Finding.
    Finding::Detail = Struct.new(:label, :text, keyword_init: true)
  end
end
