# frozen_string_literal: true

require "spec_helper"

RSpec.describe AgentHarnessRails::Installer do
  describe "#install" do
    it "vendors the payload and records ownership" do
      result = install

      expect(result).to be_clean
      expect(result.written).to include(owned_relative_path)
      expect(File).to exist(payload_path(owned_relative_path))
      expect(manifest["version"]).to eq(AgentHarnessRails::VERSION)
      expect(manifest["owns"]).to include(owned_relative_path)
    end

    it "keeps skills flat, because Claude Code does not recurse" do
      install

      skill_files = Dir.glob(payload_path("skills", "**", "SKILL.md"))
      depths = skill_files.map { |p| p.delete_prefix("#{payload_path("skills")}/").count("/") }

      expect(depths.uniq).to eq([ 1 ]), "expected every SKILL.md at skills/<name>/SKILL.md"
    end

    it "creates one relative symlink per editor surface" do
      install

      described_class::LINKS.each_key do |target|
        absolute = File.join(project, target)
        expect(File.symlink?(absolute)).to be(true), "#{target} should be a symlink"
        expect(File.readlink(absolute)).to start_with(".."), "#{target} should be relative"
        expect(File).to exist(absolute), "#{target} should resolve"
      end
    end

    it "exposes a skill's references/ through the container link" do
      install

      expect(Dir).to exist(File.join(project, ".claude/skills/writing-tests/references"))
    end

    it "is idempotent — a second run copies nothing" do
      install
      result = install

      expect(result.written).to be_empty
      expect(result.unchanged.size).to eq(manifest["owns"].size)
    end

    it "preserves a local edit to a gem-owned file" do
      install
      File.write(payload_path(owned_relative_path), "locally rewritten\n")

      result = install

      expect(result.overridden).to eq([ owned_relative_path ])
      expect(File.read(payload_path(owned_relative_path))).to eq("locally rewritten\n")
    end

    it "leaves app-authored files alone and out of the manifest" do
      write_app_file("skills/our-house-style/SKILL.md", "app authored\n")

      install

      expect(File.read(payload_path("skills/our-house-style/SKILL.md"))).to eq("app authored\n")
      expect(manifest["owns"]).not_to include("skills/our-house-style/SKILL.md")
    end

    it "refuses to overwrite an unowned file whose name collides" do
      colliding = write_app_file("skills/writing-models/SKILL.md", "app authored\n")

      result = install

      expect(result).not_to be_clean
      expect(result.collisions).to include("skills/writing-models/SKILL.md")
      expect(File.read(colliding)).to eq("app authored\n")
    end

    it "writes nothing at all when a collision is detected" do
      write_app_file("skills/writing-models/SKILL.md", "app authored\n")

      install

      expect(File).not_to exist(payload_path(owned_relative_path))
    end

    it "removes files it used to own once the gem stops shipping them" do
      install
      stale = payload_path("rules/retired.mdc")
      File.write(stale, "retired\n")

      # Pretend the previous version owned it, with the digest it has now.
      path = payload_path(AgentHarnessRails::Manifest::FILENAME)
      data = JSON.parse(File.read(path))
      data[AgentHarnessRails::Manifest::INSTALLER_KEY]["owns"]["rules/retired.mdc"] =
        AgentHarnessRails::Manifest.digest(stale)
      File.write(path, JSON.pretty_generate(data))

      result = install

      expect(result.pruned).to include("rules/retired.mdc")
      expect(File).not_to exist(stale)
    end

    it "keeps a formerly-owned file the app has since edited" do
      install
      stale = payload_path("rules/retired.mdc")
      File.write(stale, "original\n")
      path = payload_path(AgentHarnessRails::Manifest::FILENAME)
      data = JSON.parse(File.read(path))
      data[AgentHarnessRails::Manifest::INSTALLER_KEY]["owns"]["rules/retired.mdc"] =
        AgentHarnessRails::Manifest.digest(stale)
      File.write(path, JSON.pretty_generate(data))
      File.write(stale, "app changed it\n")

      result = install

      expect(result.pruned).not_to include("rules/retired.mdc")
      expect(File.read(stale)).to eq("app changed it\n")
    end

    context "with mode: :copy" do
      it "creates real directories instead of symlinks" do
        install(mode: :copy)

        expect(Dir.glob(File.join(project, "**", "*"), File::FNM_DOTMATCH).select { |p| File.symlink?(p) })
          .to be_empty
        expect(File).to exist(File.join(project, ".claude/skills/writing-models/SKILL.md"))
      end
    end

    it "rejects an unknown mode" do
      expect { described_class.new(project_root: project, mode: :hardlink) }
        .to raise_error(AgentHarnessRails::Error, /link or :copy/)
    end
  end

  describe "#check" do
    it "reports uninstalled when there is no manifest" do
      expect(check).to eq([ :uninstalled, [] ])
    end

    it "reports ok on a fresh install" do
      install
      status, findings = check

      expect(status).to eq(:ok)
      expect(findings).to be_empty
    end

    it "reports a local override without blocking" do
      install
      File.write(payload_path(owned_relative_path), "locally rewritten\n")

      status, findings = check

      expect(status).to eq(:ok)
      expect(findings).to include("overridden: #{owned_relative_path}")
    end

    it "blocks when an owned file is missing" do
      install
      FileUtils.rm(payload_path(owned_relative_path))

      status, findings = check

      expect(status).to eq(:drifted)
      expect(findings).to include("missing: #{owned_relative_path}")
    end

    it "blocks when an editor link is gone" do
      install
      FileUtils.rm(File.join(project, ".cursor/rules/harness"))

      status, findings = check

      expect(status).to eq(:drifted)
      expect(findings).to include("link missing: .cursor/rules/harness")
    end

    it "blocks when the vendored version predates the gem" do
      install
      path = payload_path(AgentHarnessRails::Manifest::FILENAME)
      data = JSON.parse(File.read(path))
      data[AgentHarnessRails::Manifest::INSTALLER_KEY]["version"] = "0.0.1"
      File.write(path, JSON.pretty_generate(data))

      status, findings = check

      expect(status).to eq(:drifted)
      expect(findings.first).to match(/version: vendored 0\.0\.1/)
    end
  end
end
