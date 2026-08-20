# frozen_string_literal: true

require "digest"
require_relative "tags"

module AgentHarnessRails
  module Evals
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
    #
    # `opener` is the line the example starts on, which is not always the tag's
    # own line — metadata wraps. `proofs` needs it to say which of a file's
    # examples are the tagged ones.
    #
    # `group` is set when the tag sits on a `describe` or `context` instead of an
    # example. There is no example around such a tag, so everything read here
    # describes the group line: no description, no assertions. It is carried
    # rather than dropped because a consumer that showed it as an ordinary proof
    # would be showing a phantom.
    Proof = Struct.new(:capability, :clause_id, :path, :line, :opener, :group, :description, :assertions,
                       :digest, keyword_init: true) do
      def clause_key = [ capability, clause_id ]

      def file_key = [ capability, clause_id, path ]

      def misplaced? = !group.nil?
    end

    # One example opener, tagged or not. The untagged ones are what turn "this
    # file is an evaluation" into "three of this file's seven examples carry the
    # tag" — the difference the file-granular checks in `Evals` cannot see.
    Example = Struct.new(:line, :description, keyword_init: true)

    module Proofs
      ASSERTION = /\b(?:expect|is_expected|assert|assert_not)\b/
      # The example's name: the first string literal on the opening line, which
      # precedes the `intent:` tag's own quoted value. The two quote styles are
      # separate alternatives rather than one `["']` class, so an apostrophe in
      # a double-quoted name — "rejects a typo'd clause" — does not end the
      # match half way through the description a reader is about to read.
      DESCRIPTION = /"([^"]*)"|'([^']*)'/

      # Reads each spec file once, whatever number of tags it carries.
      def self.read(tags, root:)
        tags.group_by(&:path).flat_map do |relative, file_tags|
          path = File.join(root, relative)
          next [] unless File.exist?(path)

          lines = File.readlines(path, chomp: true, encoding: "UTF-8")
          file_tags.map { |tag| build(tag, lines) }
        end
      end

      # Every example in a file, in source order. Group openers are skipped:
      # a `describe` is not a candidate proof, and counting it would inflate the
      # denominator of a ratio a reader is about to compare with a plan.
      def self.examples(lines)
        lines.each_with_index.filter_map do |line, index|
          next unless Tags.example_opener?(line)

          Example.new(line: index + 1, description: description_of(line))
        end
      end

      def self.build(tag, lines)
        opener = opener_index(lines, tag.line - 1)
        body = body_of(lines, tag.line - 1, opener)

        Proof.new(capability: tag.capability, clause_id: tag.clause_id, path: tag.path, line: tag.line,
                  opener: opener ? opener + 1 : tag.line, group: tag.group,
                  description: opener && description_of(lines[opener]),
                  assertions: body.count { |line| ASSERTION.match?(line) },
                  digest: Digest::SHA256.hexdigest(body.join("\n")))
      end

      def self.description_of(line) = DESCRIPTION.match(line.to_s)&.captures&.compact&.first

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
        index.downto([ index - Tags::LOOKBACK, 0 ].max) do |candidate|
          return candidate if Tags.example_opener?(lines[candidate])
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
          return index - 1 if sibling.match?(line) && Tags.example_opener?(line)
        end

        opener
      end

      # `it("replies", intent: "x") { expect(…).to be(true) }` closes on its own
      # line. A trailing `do` (or an opening `{` with the body below) does not.
      def self.one_liner?(line) = line.to_s.rstrip.end_with?("}")

      private_class_method :build, :body_of, :opener_index, :closing_index, :one_liner?, :description_of
    end
  end
end
