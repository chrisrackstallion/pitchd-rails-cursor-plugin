# frozen_string_literal: true

require "open3"
require "tmpdir"

module AgentHarnessRails
  module Guard
    # The "before" side of the comparison: the primitives tree and the spec suite
    # as they stood at a base revision, extracted into a temp directory.
    #
    # Materialised as files rather than read as blobs so the *same* parsers read
    # both sides — `Evals::Capability` and `Evals::Tags` take a directory, and a
    # second blob-reading path for the base would be a second thing to keep in
    # step with the format.
    module Baseline
      # Every git call goes through here: no shell, so a branch name with a
      # space or a `;` in it is an argument rather than a command.
      def self.git(root, *args)
        out, err, status = Open3.capture3("git", "-C", root, *args)
        [ status.success?, out, err ]
      end

      # Yields [ directory, resolved ref ]. The directory holds only the paths
      # that existed at that revision, so a capability tree added on this branch
      # yields an empty baseline rather than an error — everything in it is new,
      # which is the one shape that never produces a notice.
      def self.capture(root:, base:, paths:)
        ref = resolve(root, base)

        Dir.mktmpdir("agent-harness-guard") do |dir|
          present = paths.select { |path| tracked?(root, ref, path) }
          extract(root, ref, present, dir) unless present.empty?
          yield dir, ref
        end
      end

      # The comparison point for `--base main` is where this work started, not
      # where main has since got to: a commit someone else pushed to main is not
      # this agent's change. Falls back to the ref itself when there is no
      # common ancestor to find.
      def self.resolve(root, base)
        raise Error, "not a git repository: #{root}" unless git(root, "rev-parse", "--git-dir").first

        ok, sha = git(root, "rev-parse", "--verify", "--quiet", "#{base}^{commit}")
        raise Error, "cannot resolve #{base.inspect} to a commit — pass an existing ref with --base" unless ok

        merged, ancestor = git(root, "merge-base", sha.strip, "HEAD")
        merged ? ancestor.strip : sha.strip
      end

      def self.tracked?(root, ref, path)
        ok, out = git(root, "ls-tree", "--name-only", ref, "--", path)
        ok && !out.strip.empty?
      end

      # `git archive` streamed straight into tar: no intermediate archive on
      # disk, and no second checkout of the working tree.
      def self.extract(root, ref, paths, dir)
        statuses = Open3.pipeline(
          [ "git", "-C", root, "archive", "--format=tar", ref, "--", *paths ],
          [ "tar", "-x", "-C", dir ]
        )
        return if statuses.all?(&:success?)

        raise Error, "could not read #{paths.join(', ')} at #{ref[0, 12]}"
      end

      private_class_method :git, :tracked?, :extract
    end
  end
end
