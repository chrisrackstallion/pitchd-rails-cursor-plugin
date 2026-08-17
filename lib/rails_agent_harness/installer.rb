# frozen_string_literal: true

require "fileutils"
require_relative "../rails_agent_harness"
require_relative "manifest"

module RailsAgentHarness
  # Vendors the payload into a project and points the editor directories at it.
  #
  # Editor directories hold nothing but links: one per surface, relative, so a
  # clone works with no per-machine step. Skills stay FLAT under
  # rails-agent-harness/skills/ because Claude Code discovers exactly
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
                        keyword_init: true) do
      def clean?
        collisions.empty?
      end
    end

    def initialize(project_root:, mode: :link, out: $stdout)
      @project_root = File.expand_path(project_root)
      @mode = mode.to_sym
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
                          collisions: [])

      plan = source_files.to_h { |relative| [ relative, classify(relative, previous) ] }
      plan.each { |relative, verdict| result.collisions << relative if verdict == :collision }
      return result unless result.clean?

      owns = {}
      plan.each do |relative, verdict|
        destination = File.join(payload_dir, relative)

        case verdict
        when :write
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(File.join(RailsAgentHarness.payload, relative), destination)
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
      base = RailsAgentHarness.payload
      Dir.glob(File.join(base, "**", "*"), File::FNM_DOTMATCH)
         .select { |path| File.file?(path) }
         .map { |path| path.delete_prefix("#{base}/") }
         .reject { |relative| File.basename(relative).start_with?(".") }
         .sort
    end

    # Ownership rules. The collision case is the important one: with a flat
    # skills/ directory an app-authored skill can genuinely share a name with a
    # vendored one, and silently overwriting it would lose the app's work.
    def classify(relative, previous)
      destination = File.join(payload_dir, relative)
      return :write unless File.exist?(destination)

      # Already current: nothing to copy, whether or not a manifest exists yet.
      source = File.join(RailsAgentHarness.payload, relative)
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

        mode == :link ? create_link(absolute, target, subdir) : create_copy(absolute, subdir)
      end
    end

    def create_link(absolute, target, subdir)
      expected = relative_link_target(target, subdir)

      if File.symlink?(absolute)
        return "unchanged #{target}" if File.readlink(absolute) == expected

        File.unlink(absolute)
      elsif File.exist?(absolute)
        raise Error, "#{target} exists and is not a symlink — move it aside or use --mode=copy"
      end

      File.symlink(expected, absolute)
      "linked    #{target} -> #{expected}"
    end

    def create_copy(absolute, subdir)
      FileUtils.rm_rf(absolute)
      FileUtils.cp_r(File.join(payload_dir, subdir), absolute)
      "copied    #{absolute.delete_prefix("#{project_root}/")}"
    end

    # `.cursor/rules/harness` sits one level deeper than `.claude/skills`, so the
    # number of hops is derived rather than hardcoded.
    def relative_link_target(target, subdir)
      hops = "../" * target.count("/")
      "#{hops}#{PAYLOAD_DIR}/#{subdir}"
    end
  end
end
