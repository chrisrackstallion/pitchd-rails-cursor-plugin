# frozen_string_literal: true

require "digest"
require_relative "../evals/tags"

module AgentHarnessRails
  module Guard
    # A tagged example, read as the proof of one clause: which file it lives in,
    # what it asserts, and a digest of its body.
    #
    # `Evals::Tags` finds where a tag sits; this reads the example around it,
    # because "the tag is still there" and "the example still proves anything"
    # are different questions and only the second one needs the body.
    #
    # Textual, like the tag scan itself — this must run with no database and no
    # Rails environment. The body is delimited by indentation: the `end` at the
    # example opener's column, or — for a `{ … }` one-liner, which has no `end`
    # to find — the opening line alone. RuboCop keeps app suites in that shape,
    # and an example this cannot delimit falls back to its opening line, which
    # reads as "changed" more often than it should rather than silently as
    # unchanged.
    Proof = Struct.new(:capability, :clause_id, :path, :line, :description, :assertions, :digest,
                       keyword_init: true) do
      def clause_key = [ capability, clause_id ]

      def file_key = [ capability, clause_id, path ]
    end

    module Proofs
      ASSERTION = /\b(?:expect|is_expected|assert|assert_not)\b/
      # The example's name: the first string literal on the opening line, which
      # precedes the `intent:` tag's own quoted value.
      DESCRIPTION = /["']([^"']*)["']/
      EXAMPLE_OPENER = /^[ \t]*(?:RSpec\.)?[fx]?(?:#{Evals::Tags::EXAMPLE_METHODS.join('|')})[\s({]/

      # Reads each spec file once, whatever number of tags it carries.
      def self.read(tags, root:)
        tags.group_by(&:path).flat_map do |relative, file_tags|
          path = File.join(root, relative)
          next [] unless File.exist?(path)

          lines = File.readlines(path, chomp: true, encoding: "UTF-8")
          file_tags.map { |tag| build(tag, lines) }
        end
      end

      def self.build(tag, lines)
        opener = opener_index(lines, tag.line - 1)
        body = body_of(lines, tag.line - 1, opener)

        Proof.new(capability: tag.capability, clause_id: tag.clause_id, path: tag.path, line: tag.line,
                  description: opener && DESCRIPTION.match(lines[opener])&.captures&.first,
                  assertions: body.count { |line| ASSERTION.match?(line) },
                  digest: Digest::SHA256.hexdigest(body.join("\n")))
      end

      # Dedented before digesting, so wrapping an example in one more `context`
      # is not reported as a change to what it proves.
      def self.body_of(lines, index, opener)
        return [ lines[index].to_s.strip ] if opener.nil?

        indent = lines[opener][/\A[ \t]*/]
        closer = closing_index(lines, opener, indent)

        lines[opener..closer].map { |line| line.delete_prefix(indent).rstrip }
      end

      # The example this tag is metadata for. Same lookback as the tag scan:
      # metadata wrapped onto its own line under a long example name is still on
      # that example.
      def self.opener_index(lines, index)
        index.downto([ index - Evals::Tags::LOOKBACK, 0 ].max) do |candidate|
          return candidate if EXAMPLE_OPENER.match?(lines[candidate].to_s)
        end

        nil
      end

      # Stops at the example's own `end`, or at the next example that starts at
      # the same column — whichever comes first. The second bound is what keeps a
      # `{ … }` one-liner from swallowing its siblings all the way down to some
      # later example's `end`, and reporting an untouched example as changed
      # every time a neighbour is added.
      def self.closing_index(lines, opener, indent)
        return opener if one_liner?(lines[opener])

        terminator = /\A#{Regexp.escape(indent)}end\b/
        sibling = /\A#{Regexp.escape(indent)}\S/

        ((opener + 1)...lines.size).each do |index|
          line = lines[index].to_s
          return index if terminator.match?(line)
          return index - 1 if sibling.match?(line) && EXAMPLE_OPENER.match?(line)
        end

        opener
      end

      # `it("replies", intent: "x") { expect(…).to be(true) }` closes on its own
      # line. A trailing `do` (or an opening `{` with the body below) does not.
      def self.one_liner?(line) = line.to_s.rstrip.end_with?("}")

      private_class_method :build, :body_of, :opener_index, :closing_index, :one_liner?
    end
  end
end
