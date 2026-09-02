# frozen_string_literal: true

require "fileutils"
require "digest"

module AgentHarnessRails
  # Moves skills, rules, and agents an app already had in .claude/ or .cursor/
  # into the harness payload, before those directories are replaced by symlinks.
  #
  # Without this, an app that authored its own skills in .claude/skills/ would
  # have them shadowed by the link (link mode) or deleted outright (copy mode,
  # which rm_rf's the target). Moving them first means the app keeps its work and
  # gets it in the one place both editors read from.
  #
  # Plans first, executes second, so a name clash aborts before anything moves.
  class Migration
    # editor directory => payload subdirectory its contents belong in
    SOURCES = {
      ".claude/skills" => "skills",
      ".claude/agents" => "agents",
      ".cursor/skills" => "skills",
      ".cursor/agents" => "agents",
      ".cursor/rules" => "rules"
    }.freeze

    # `.cursor/rules` keeps holding the nested `harness` link, so it is emptied
    # of app content but never removed. The others are replaced wholesale.
    KEEPS_DIRECTORY = [ ".cursor/rules" ].freeze
    RESERVED_ENTRIES = [ "harness" ].freeze

    Move = Struct.new(:source, :destination, :relative, :from, keyword_init: true)
    Clash = Struct.new(:relative, :from, keyword_init: true)

    Plan = Struct.new(:moves, :duplicates, :clashes, :emptied, keyword_init: true) do
      def any?
        moves.any? || duplicates.any?
      end

      def clean?
        clashes.empty?
      end
    end

    def initialize(project_root:, payload_dir:, source_dir: AgentHarnessRails.payload)
      @project_root = project_root
      @payload_dir = payload_dir
      @source_dir = source_dir
    end

    def plan
      result = Plan.new(moves: [], duplicates: [], clashes: [], emptied: [])

      SOURCES.each do |editor_dir, subdir|
        absolute = File.join(@project_root, editor_dir)
        next unless migratable?(absolute)

        entries(absolute).each { |entry| classify(entry, editor_dir, absolute, subdir, result) }
        result.emptied << editor_dir unless KEEPS_DIRECTORY.include?(editor_dir)
      end

      result
    end

    # Executes a clean plan. Duplicates are dropped rather than moved — the app's
    # copy is byte-identical to what is already vendored, so keeping it would just
    # be a second copy of the same file.
    def apply(plan)
      raise Error, "refusing to apply a plan with clashes" unless plan.clean?

      plan.moves.each do |move|
        FileUtils.mkdir_p(File.dirname(move.destination))
        FileUtils.mv(move.source, move.destination)
      end

      plan.duplicates.each { |move| FileUtils.rm_rf(move.source) }
      plan.emptied.each { |dir| remove_if_empty(File.join(@project_root, dir)) }
      plan
    end

    private

    # A symlink is already pointing somewhere — nothing of the app's lives here.
    def migratable?(absolute)
      File.directory?(absolute) && !File.symlink?(absolute)
    end

    def entries(absolute)
      Dir.children(absolute)
         .reject { |name| RESERVED_ENTRIES.include?(name) || name.start_with?(".") }
         .sort
         .map { |name| File.join(absolute, name) }
    end

    # The path is contested if something is already vendored there, or if the gem
    # is about to vendor there. Compare against whichever applies: identical
    # content is a duplicate to drop, differing content is a clash the user must
    # resolve by renaming, and an uncontested path is a plain move.
    def classify(entry, editor_dir, absolute, subdir, result)
      relative = File.join(subdir, entry.delete_prefix("#{absolute}/"))
      destination = File.join(@payload_dir, relative)
      move = Move.new(source: entry, destination: destination, relative: relative, from: editor_dir)

      rival = [ destination, File.join(@source_dir, relative) ].find { |path| File.exist?(path) }

      if rival.nil?
        result.moves << move
      elsif identical?(entry, rival)
        result.duplicates << move
      else
        result.clashes << Clash.new(relative: relative, from: editor_dir)
      end
    end

    def identical?(source, destination)
      return false unless File.directory?(source) == File.directory?(destination)
      return Digest::SHA256.file(source) == Digest::SHA256.file(destination) unless File.directory?(source)

      fingerprint(source) == fingerprint(destination)
    end

    # Relative-path + content digest of a whole directory, so an app's copy of a
    # skill is recognised as the same skill.
    def fingerprint(dir)
      Dir.glob(File.join(dir, "**", "*")).select { |p| File.file?(p) }.sort.map do |path|
        [ path.delete_prefix("#{dir}/"), Digest::SHA256.file(path).hexdigest ]
      end
    end

    def remove_if_empty(dir)
      Dir.rmdir(dir) if File.directory?(dir) && !File.symlink?(dir) && Dir.children(dir).empty?
    end
  end
end
