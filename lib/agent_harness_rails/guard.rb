# frozen_string_literal: true

require_relative "../agent_harness_rails"
require_relative "evals"
require_relative "guard/baseline"
require_relative "guard/proof"

module AgentHarnessRails
  # Reports what a change did to the promises in docs/primitives/ and to the
  # specs that prove them.
  #
  # `Evals` asks a stateless question — is every clause hooked up to a spec right
  # now — and a whole class of drift passes it. Reword a clause under the same
  # id, hollow out a tagged example, move a browser promise onto a model spec:
  # the links stay well-formed and the run stays green while the record quietly
  # stops describing the app. Catching that needs a *before*, which is what this
  # adds by parsing the tree twice, at the base revision and in the working tree.
  #
  # Everything here is a **notice**. Nothing fails, nothing blocks, and the exit
  # code is 0 whenever the comparison ran — because every check in it has a
  # legitimate cause as well as a suspicious one, and a check that stops honest
  # work is a check that gets routed around. The audience is a person deciding
  # whether the agent's change to the record was the one they asked for; the
  # agent reading its own notices mid-turn gets to put back a proof it dropped
  # by accident. What an agent must not do is *discharge* a notice about intent
  # by writing the provenance line that silences it — that hands the tool the
  # job of laundering the change it was built to surface. Intent notices go to
  # the user.
  #
  # Growth is silent by design: new clauses, new tagged examples, added
  # evaluations and appended provenance produce nothing. Only the record getting
  # smaller or different is worth a person's attention.
  module Guard
    DEFAULT_BASE = "HEAD"
    PROVENANCE_HEADING = /^##\s+Provenance\s*$/
    PROVENANCE_ENTRY = /^\s*[-*]\s+(.+)$/
    NEXT_HEADING = /^##\s+/

    # Statuses ordered by how much they promise. `deprecated` sits below
    # `shaping` deliberately: it is the one status that retires a capability's
    # obligations wholesale, so arriving at it is always worth a line.
    #
    # Anything unrecognised ranks below all of them, so `built` → a typo reads as
    # the downgrade it is. Ranking an unknown status *above* `built` would let the
    # single most consequential edit — shedding every obligation the status
    # carried — pass as no change at all.
    STATUS_RANK = { "deprecated" => 0, "shaping" => 1, "planned" => 2, "built" => 3 }.freeze
    UNKNOWN_STATUS_RANK = -1

    # Codes from `Evals::Capability` meaning the clauses could not be read at all.
    UNREADABLE_CODES = %w[doc/malformed doc/legacy-format].freeze

    Result = Struct.new(:findings, :base, :capabilities, keyword_init: true) do
      def notices = findings
      def clean? = findings.empty?
    end

    # One side of the comparison: capability docs by name, their provenance
    # lines, and every tagged example in the suite.
    Snapshot = Struct.new(:capabilities, :provenance, :proofs, keyword_init: true) do
      def capability(name) = capabilities[name]
    end

    class << self
      def run(root:, base: DEFAULT_BASE, primitives_dir: Evals::DEFAULT_PRIMITIVES_DIR,
              specs_dir: Evals::DEFAULT_SPECS_DIR)
        capabilities_dir = File.join(primitives_dir, Evals::CAPABILITIES_SUBDIR)
        unless Dir.exist?(File.join(root, capabilities_dir))
          raise Error, "no capability docs at #{capabilities_dir}/"
        end

        current = snapshot(root, capabilities_dir, specs_dir)

        Baseline.capture(root: root, base: base, paths: [ primitives_dir, specs_dir ]) do |dir, ref|
          Result.new(findings: sort(compare(snapshot(dir, capabilities_dir, specs_dir), current)),
                     base: ref, capabilities: current.capabilities.size)
        end
      end

      private

      def snapshot(root, capabilities_dir, specs_dir)
        docs = Evals::Capability.load_all(File.join(root, capabilities_dir), root: root)
        tags, = Evals::Tags.scan(File.join(root, specs_dir), root: root)

        Snapshot.new(capabilities: docs.to_h { |doc| [ doc.name, doc ] },
                     provenance: docs.to_h { |doc| [ doc.name, provenance_of(doc.path) ] },
                     proofs: Proofs.read(tags, root: root))
      end

      # Entries under `## Provenance`, one per bullet, with runs of internal
      # whitespace squeezed so re-spacing a line is not read as rewriting it.
      # A provenance entry is one line by rule (`agent_harness_rails/rules/primitives.mdc`
      # § Provenance — a multi-line entry is a lint finding), so a bullet wrapped
      # onto a second line is itself an edit worth reporting, and its
      # continuation is deliberately not stitched back on.
      def provenance_of(path)
        lines = File.readlines(path, chomp: true, encoding: "UTF-8")
        start = lines.index { |line| PROVENANCE_HEADING.match?(line) }
        return [] if start.nil?

        lines[(start + 1)..].to_a
                            .take_while { |line| !NEXT_HEADING.match?(line) }
                            .filter_map { |line| PROVENANCE_ENTRY.match(line)&.captures&.first&.squeeze(" ")&.strip }
      end

      def compare(base, current)
        base.capabilities.flat_map { |name, doc| capability_findings(name, doc, base, current) } +
          proof_findings(base, current)
      end

      def capability_findings(name, was, base, current)
        now = current.capability(name)
        return [ removed_doc(was) ] if now.nil?

        # A doc that no longer parses has no clauses to compare, and comparing
        # anyway reports every clause as deleted — a cascade that describes the
        # parse failure as eleven separate decisions nobody made.
        unreadable = unreadable_findings(now)
        return unreadable if unreadable.any?

        clause_findings(was, now, discharged_ids(base.provenance[name], current.provenance[name])) +
          status_findings(was, now) +
          provenance_findings(now, base.provenance[name], current.provenance[name])
      end

      # Only when the doc yielded **nothing**. `doc/malformed` also covers faults
      # a doc survives — an unrecognised `status:`, one bad clause entry — and
      # those leave clauses readable, so they are `evals`' business rather than a
      # reason to stop comparing.
      def unreadable_findings(now)
        return [] unless now.clauses.empty?

        now.findings.select { |finding| UNREADABLE_CODES.include?(finding.code) }.map do |finding|
          notice(now.relative_path, finding.line,
                 "this doc no longer parses, so what it promises cannot be compared with what it " \
                 "promised — #{finding.message}",
                 "doc/unreadable")
        end
      end

      def removed_doc(was)
        notice(was.relative_path, 1,
               "capability doc deleted — #{was.active_clauses.size} active clause(s) went with it; " \
               "a capability that is gone is normally `status: deprecated` with a provenance entry, " \
               "so the promises it made stay readable",
               "doc/removed")
      end

      def status_findings(was, now)
        return [] unless rank(now.status) < rank(was.status)

        [ notice(now.relative_path, 1,
                 "status went #{was.status} → #{now.status || '(none)'}, which drops the coverage this doc owed",
                 "status/downgraded") ]
      end

      def rank(status) = STATUS_RANK.fetch(status, UNKNOWN_STATUS_RANK)

      # Provenance is append-only, and it is also the trace every other notice
      # here is discharged against — so an edit to it is the one change that
      # degrades the record's ability to describe the next one.
      #
      # Compared as a prefix rather than as a set: entries are appended at the
      # end, so the old list must still be the front of the new one. A set
      # difference would miss a reordering, and would miss deleting one of two
      # identical entries. Only the first divergence is reported — inserting a
      # line mid-history moves every entry after it, and eleven notices for one
      # edit describe it worse than one does.
      def provenance_findings(now, before, after)
        index = before.each_index.find { |i| after[i] != before[i] }
        return [] if index.nil?

        [ notice(now.relative_path, 1,
                 "provenance entry #{summarise(before[index])} was edited, removed, or reordered — provenance " \
                 "is append-only: new entries go at the end, and a wrong entry is corrected by a new entry",
                 "provenance/rewritten") ]
      end

      def clause_findings(was, now, discharged)
        was.clauses.flat_map do |before|
          after = now.clause(before.id)
          next [ vanished(now, before) ] if after.nil?
          next [ deactivated(now, before, after) ] if before.active? && !after.active?
          next [] unless after.active?

          rewritten(was, now, before, after, discharged) + evaluation_findings(now, before, after)
        end
      end

      def vanished(now, before)
        notice(now.relative_path, 1,
               "#{before.id} is gone — #{summarise(before.text)}. Ids are never deleted or reused: " \
               "supersede it with `superseded_by:` so a future reader learns the promise existed and why it went",
               "intent/vanished")
      end

      def deactivated(now, before, after)
        verb = after.retired_on ? "retired" : "superseded by #{after.superseded_by.join(', ')}"

        notice(now.relative_path, after.line,
               "#{before.id} was #{verb} — #{summarise(before.text)}. The sanctioned path, and " \
               "worth confirming it was asked for",
               "intent/deactivated")
      end

      # In-place rewording is legitimate while a doc is still drafting; it stops
      # being legitimate once a plan has been approved against those clauses,
      # which is what `planned` and `built` mark.
      def rewritten(was, now, before, after, discharged)
        return [] unless %w[planned built].include?(was.status)
        return [] if before.text.to_s.strip == after.text.to_s.strip
        return [] if discharged.include?(before.id)

        [ notice(now.relative_path, after.line,
                 "#{before.id} now promises something else, under the same id and with no provenance entry. " \
                 "Was: #{summarise(before.text)}. Now: #{summarise(after.text)}. An amendment supersedes " \
                 "the old clause and records the decision — only the user's decision changes intent",
                 "intent/rewritten") ]
      end

      # Three outcomes, because "this clause names a different file now" and
      # "this clause names one fewer file" are different events and only the
      # second one is a loss of coverage.
      def evaluation_findings(now, before, after)
        dropped = before.evaluations - after.evaluations
        return [] if dropped.empty?

        added = after.evaluations - before.evaluations
        relayered_to = added.reject { |path| layers(dropped).include?(layer(path)) }

        return [ relayered(now, after, dropped, relayered_to) ] if relayered_to.any?
        return [ moved_evaluation(now, after, dropped, added) ] if added.any?

        [ dropped_evaluation(now, after, dropped) ]
      end

      def relayered(now, after, dropped, moved)
        notice(now.relative_path, after.line,
               "#{after.id} moved its proof from #{dropped.join(', ')} to #{moved.join(', ')} — a clause " \
               "is only proven at a layer that can hold it, so check the new home can fail for the " \
               "reason the old one could",
               "evaluation/relayered")
      end

      # Same layer, so the clause is not proven by less — it is proven somewhere
      # else, and whether the new file proves the same thing is the open question.
      def moved_evaluation(now, after, dropped, added)
        notice(now.relative_path, after.line,
               "#{after.id} moved its proof from #{dropped.join(', ')} to #{added.join(', ')} at the same " \
               "layer — confirm the new file proves what the old one did",
               "evaluation/moved")
      end

      def dropped_evaluation(now, after, dropped)
        notice(now.relative_path, after.line,
               "#{after.id} no longer names #{dropped.join(', ')} — an active clause is proven by less " \
               "than it was",
               "evaluation/dropped")
      end

      # Examples are compared per (clause, file) rather than by name, so renaming
      # one reads as a change to it and never as a deletion plus an unrelated
      # addition.
      #
      # Within a group, identical bodies are paired off **first**. Pairing purely
      # by position would report a spurious change for every untouched example
      # that a new sibling was inserted above — which breaks the one invariant
      # this tool is sold on, that growth is silent.
      def proof_findings(base, current)
        after = current.proofs.group_by(&:file_key)

        base.proofs.group_by(&:file_key).flat_map do |key, before|
          next [] unless still_owed?(current, key)

          now = after[key] || []
          gone = now.size < before.size ? [ vanished_proof(before, now.size) ] : []

          gone + align(before, now).flat_map { |was, is| changed_proof(was, is) }
        end
      end

      # Pairs each example with what it became, in three passes: identical bodies
      # first (nothing to say about those), then same name with a changed body,
      # then whatever is left, by position — which is what makes a rename read as
      # a change rather than as a deletion.
      #
      # The name pass is what keeps the pairing honest when the counts differ:
      # position alone would marry a deleted example to an unrelated survivor and
      # describe the pair as one edit.
      def align(before, now)
        remaining = now.dup
        changed = before.reject { |was| take(remaining) { |is| is.digest == was.digest } }
        named, rest = changed.partition { |was| was.description && remaining.any? { |is| is.description == was.description } }

        named.map { |was| [ was, take(remaining) { |is| is.description == was.description } ] } +
          rest.each_with_index.map { |was, index| [ was, remaining[index] ] }
      end

      # Removes the first match from `list` and returns it, or nil.
      def take(list, &)
        index = list.index(&)
        index && list.delete_at(index)
      end

      # A proof that went with a clause its change also tombstoned is not a
      # missing proof — the promise it covered is no longer being made.
      def still_owed?(current, (name, clause_id, _path))
        capability = current.capability(name)
        return false if capability.nil?

        clause = capability.clause(clause_id)
        !clause.nil? && clause.active?
      end

      def vanished_proof(before, remaining)
        gone = before.size - remaining
        first = before.first

        notice(first.path, remaining.zero? ? 1 : first.line,
               "#{gone} tagged example(s) for #{first.capability}##{first.clause_id} " \
               "#{gone == 1 ? 'is' : 'are'} gone from this file, and the clause is still active",
               "proof/removed")
      end

      def changed_proof(was, is)
        return [] if is.nil? || was.digest == is.digest

        if is.assertions < was.assertions
          [ notice(is.path, is.line,
                   "the example proving #{is.capability}##{is.clause_id} lost #{was.assertions - is.assertions} " \
                   "assertion(s) — it still carries the tag while proving less of the clause",
                   "proof/weakened") ]
        else
          [ notice(is.path, is.line,
                   "the example proving #{is.capability}##{is.clause_id} changed — confirm it can still fail " \
                   "for the reason the clause could stop being true",
                   "proof/changed") ]
        end
      end

      # A clause id named by a provenance entry this change added. The record of
      # the decision is what separates an amendment from a rewrite — and writing
      # that line is the user's call, not the agent's.
      def discharged_ids(before, after)
        (after - before).flat_map { |entry| entry.scan(/\bI[1-9]\d*\b/) }.uniq
      end

      def layers(paths) = paths.map { |path| layer(path) }

      # spec/system/comment_threads_spec.rb → "system"
      def layer(path) = path.split("/")[1]

      def summarise(text, limit: 70)
        one_line = text.to_s.squeeze(" ").strip.tr("\n", " ")
        one_line.length > limit ? "#{one_line[0, limit - 1]}…".inspect : one_line.inspect
      end

      def notice(path, line, message, code)
        Evals::Finding.new(severity: :notice, path: path, line: line, column: 1, message: message, code: code)
      end

      def sort(findings)
        findings.sort_by { |finding| [ finding.path, finding.line, finding.code ] }
      end
    end
  end
end
