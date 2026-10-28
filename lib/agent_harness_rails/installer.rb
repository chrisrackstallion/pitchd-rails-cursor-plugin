# frozen_string_literal: true

require "fileutils"
require_relative "../agent_harness_rails"
require_relative "manifest"
require_relative "migration"

module AgentHarnessRails
  # Vendors the payload into a project and points the editor directories at it.
  #
  # Editor directories hold nothing but links: one per surface, relative, so a
  # clone works with no per-machine step. Skills stay FLAT under
  # agent_harness_rails/skills/ because Claude Code discovers exactly
  # <root>/<name>/SKILL.md and does not recurse.
  class Installer
    # target => path within the payload it points at
    LINKS = {
      ".claude/skills" => "skills",
      ".claude/agents" => "agents",
      ".cursor/skills" => "skills",
      ".cursor/agents" => "agents",
      ".cursor/rules/harness" => "rules"
    }.freeze

    Result = Struct.new(:written, :unchanged, :overridden, :pruned, :links, :collisions,
                        :migrated, :migration_clashes,
                        keyword_init: true) do
      def clean?
        collisions.empty? && migration_clashes.empty?
      end
    end

    def initialize(project_root:, mode: :link, migrate: true, out: $stdout)
      @project_root = File.expand_path(project_root)
      @mode = mode.to_sym
      @migrate = migrate
      @out = out
      raise Error, "mode must be :link or :copy" unless [ :link, :copy ].include?(@mode)
    end

    attr_reader :project_root, :mode

    def payload_dir
      File.join(project_root, PAYLOAD_DIR)
    end

    def install
      previous = Manifest.load(payload_dir)
      result = Result.new(written: [], unchanged: [], overridden: [], pruned: [], links: [],
                          collisions: [], migrated: [], migration_clashes: [])

      # Rescue the app's own skills/rules/agents from the editor directories before
      # symlinks replace them. Planned, not applied, so a clash aborts untouched.
      migration = Migration.new(project_root: project_root, payload_dir: payload_dir)
      migration_plan = @migrate ? migration.plan : nil
      result.migration_clashes.concat(migration_plan.clashes) if migration_plan

      plan = source_files.to_h { |relative| [ relative, classify(relative, previous) ] }
      plan.each { |relative, verdict| result.collisions << relative if verdict == :collision }
      return result unless result.clean?

      # Only real moves are reported; duplicates — app copies byte-identical to
      # the vendored file — are dropped quietly, as the README promises.
      if migration_plan&.any?
        migration.apply(migration_plan)
        result.migrated.concat(migration_plan.moves)
      end

      owns = {}
      plan.each do |relative, verdict|
        destination = File.join(payload_dir, relative)

        case verdict
        when :write
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(File.join(AgentHarnessRails.payload, relative), destination)
          result.written << relative
          owns[relative] = Manifest.digest(destination)
        when :unchanged
          result.unchanged << relative
          owns[relative] = Manifest.digest(destination)
        when :override
          result.overridden << relative
          owns[relative] = previous.owns[relative]
        end
      end

      result.pruned.concat(prune(previous, plan.keys))
      Manifest.new(version: VERSION, owns: owns).write(payload_dir)
      result.links.concat(link_editor_dirs)
      result
    end

    # Compares the vendored payload against what this gem ships.
    # Returns [status, findings] where status is :ok, :drifted, or :uninstalled.
    def check
      manifest = Manifest.load(payload_dir)
      return [ :uninstalled, [] ] if manifest.owns.empty?

      findings = []
      findings << "version: vendored #{manifest.version}, gem #{VERSION}" if manifest.version != VERSION

      missing = []
      overridden = []
      manifest.owns.each_key do |relative|
        absolute = File.join(payload_dir, relative)
        if !File.exist?(absolute)
          missing << relative
        elsif !manifest.unmodified?(relative, absolute)
          overridden << relative
        end
      end

      missing.each { |r| findings << "missing: #{r}" }
      overridden.each { |r| findings << "overridden: #{r}" }

      broken = LINKS.keys.reject { |target| File.exist?(File.join(project_root, target)) }
      broken.each { |target| findings << "link missing: #{target}" }

      blocking = missing.any? || broken.any? || manifest.version != VERSION
      [ blocking ? :drifted : :ok, findings ]
    end

    private

    def source_files
      base = AgentHarnessRails.payload
      Dir.glob(File.join(base, "**", "*"), File::FNM_DOTMATCH)
         .select { |path| File.file?(path) }
         .map { |path| path.delete_prefix("#{base}/") }
         .reject { |relative| File.basename(relative).start_with?(".") }
         .reject { |relative| AgentHarnessRails.dev_only?(relative) }
         .sort
    end

    # Ownership rules. The collision case is the important one: with a flat
    # skills/ directory an app-authored skill can genuinely share a name with a
    # vendored one, and silently overwriting it would lose the app's work.
    def classify(relative, previous)
      destination = File.join(payload_dir, relative)
      return :write unless File.exist?(destination)

      # Already current: nothing to copy, whether or not a manifest exists yet.
      source = File.join(AgentHarnessRails.payload, relative)
      return :unchanged if Manifest.digest(destination) == Manifest.digest(source)

      return :write if previous.unmodified?(relative, destination)
      return :override if previous.owns?(relative)

      :collision
    end

    # Removes files this gem used to own that it no longer ships, leaving any the
    # app has since edited.
    def prune(previous, current)
      (previous.owns.keys - current).filter_map do |relative|
        absolute = File.join(payload_dir, relative)
        next unless previous.unmodified?(relative, absolute)

        FileUtils.rm_f(absolute)
        relative
      end
    end

    def link_editor_dirs
      LINKS.map do |target, subdir|
        absolute = File.join(project_root, target)
        FileUtils.mkdir_p(File.dirname(absolute))

        mode == :link ? create_link(absolute, target, subdir) : create_copy(absolute, target, subdir)
      end
    end

    def create_link(absolute, target, subdir)
      expected = relative_link_target(target, subdir)

      if File.symlink?(absolute)
        return "unchanged #{target}" if File.readlink(absolute) == expected

        File.unlink(absolute)
      elsif File.exist?(absolute)
        # Migration empties and removes these, so anything still here is either
        # migration-disabled or not a directory at all.
        raise Error, "#{target} exists and is not a symlink — move it aside, " \
                     "or drop --no-migrate so its contents move into #{PAYLOAD_DIR}/"
      end

      File.symlink(expected, absolute)
      "linked    #{target} -> #{expected}"
    end

    # Only ever removes a directory migration has already emptied of app content,
    # or one this installer previously copied. Refuses anything else rather than
    # rm_rf'ing work it does not own.
    def create_copy(absolute, target, subdir)
      if File.exist?(absolute) && !@migrate
        raise Error, "#{target} exists and migration is disabled — move it aside or drop --no-migrate"
      end

      FileUtils.rm_rf(absolute)
      FileUtils.cp_r(File.join(payload_dir, subdir), absolute)
      "copied    #{target}"
    end

    # `.cursor/rules/harness` sits one level deeper than `.claude/skills`, so the
    # number of hops is derived rather than hardcoded.
    def relative_link_target(target, subdir)
      hops = "../" * target.count("/")
      "#{hops}#{PAYLOAD_DIR}/#{subdir}"
    end
  end
end
