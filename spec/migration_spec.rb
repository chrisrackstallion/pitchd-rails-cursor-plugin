# frozen_string_literal: true

require "spec_helper"

# The editor directories become symlinks, so anything the app already had in them
# would be shadowed (link mode) or deleted (copy mode, which rm_rf's the target).
# These examples pin the rescue.
RSpec.describe AgentHarnessRails::Migration do
  def write(relative, body)
    path = File.join(project, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    path
  end

  describe "moving app content out of the editor directories" do
    it "moves an app-authored skill, with its references/, into the harness" do
      write(".claude/skills/our-house-style/SKILL.md", "app skill\n")
      write(".claude/skills/our-house-style/references/detail.md", "app detail\n")

      install

      expect(File.read(payload_path("skills/our-house-style/SKILL.md"))).to eq("app skill\n")
      expect(File.read(payload_path("skills/our-house-style/references/detail.md"))).to eq("app detail\n")
    end

    it "moves app agents from both editors" do
      write(".claude/agents/our-deploy-agent.md", "claude agent\n")
      write(".cursor/agents/our-cursor-agent.md", "cursor agent\n")

      install

      expect(File.read(payload_path("agents/our-deploy-agent.md"))).to eq("claude agent\n")
      expect(File.read(payload_path("agents/our-cursor-agent.md"))).to eq("cursor agent\n")
    end

    it "moves app rules while leaving .cursor/rules in place for the nested link" do
      write(".cursor/rules/our-rule.mdc", "app rule\n")

      install

      expect(File.read(payload_path("rules/our-rule.mdc"))).to eq("app rule\n")
      expect(File.symlink?(File.join(project, ".cursor/rules/harness"))).to be(true)
      expect(File).not_to exist(File.join(project, ".cursor/rules/our-rule.mdc"))
    end

    it "makes migrated content visible through both editors, not just its original one" do
      write(".claude/skills/claude-only/SKILL.md", "was claude only\n")

      install

      expect(File).to exist(File.join(project, ".cursor/skills/claude-only/SKILL.md"))
    end

    it "does not claim migrated app content in the manifest" do
      write(".claude/skills/our-house-style/SKILL.md", "app skill\n")

      install

      expect(manifest["owns"].keys).not_to include("skills/our-house-style/SKILL.md")
    end

    it "reports what it moved" do
      write(".claude/skills/our-house-style/SKILL.md", "app skill\n")

      result = install

      expect(result.migrated.map(&:relative)).to eq([ "skills/our-house-style" ])
    end

    it "drops an app copy that is byte-identical to what the gem ships" do
      source = File.join(AgentHarnessRails.payload, "rules/models.mdc")
      write(".cursor/rules/models.mdc", File.read(source))

      result = install

      expect(result.migration_clashes).to be_empty
      expect(File).not_to exist(File.join(project, ".cursor/rules/models.mdc"))
      expect(File.read(payload_path("rules/models.mdc"))).to eq(File.read(source))
    end
  end

  describe "when a migrated name clashes with vendored content" do
    before { write(".claude/skills/writing-models/SKILL.md", "our different version\n") }

    it "reports the clash instead of moving" do
      result = install

      expect(result).not_to be_clean
      expect(result.migration_clashes.map(&:relative)).to include("skills/writing-models")
    end

    it "leaves the app's file exactly where it was" do
      install

      expect(File.read(File.join(project, ".claude/skills/writing-models/SKILL.md")))
        .to eq("our different version\n")
    end

    it "aborts before vendoring or linking anything" do
      install

      expect(Dir.glob(payload_path("**/*")).select { |p| File.file?(p) }).to be_empty
      expect(Dir.glob(File.join(project, "**/*"), File::FNM_DOTMATCH).select { |p| File.symlink?(p) })
        .to be_empty
    end
  end

  describe "copy mode" do
    it "rescues app content that rm_rf would otherwise have destroyed" do
      write(".claude/skills/our-skill/SKILL.md", "must survive\n")

      install(mode: :copy)

      expect(File.read(payload_path("skills/our-skill/SKILL.md"))).to eq("must survive\n")
      expect(File.read(File.join(project, ".claude/skills/our-skill/SKILL.md"))).to eq("must survive\n")
    end
  end

  describe "with migration disabled" do
    it "refuses rather than replacing a populated editor directory" do
      write(".claude/skills/our-skill/SKILL.md", "keep me\n")

      expect { AgentHarnessRails::Installer.new(project_root: project, migrate: false).install }
        .to raise_error(AgentHarnessRails::Error, /--no-migrate/)

      expect(File.read(File.join(project, ".claude/skills/our-skill/SKILL.md"))).to eq("keep me\n")
    end
  end

  describe "an already-linked project" do
    it "has nothing to migrate on a second install" do
      write(".claude/skills/our-skill/SKILL.md", "app skill\n")
      install

      result = install

      expect(result.migrated).to be_empty
      expect(File.read(payload_path("skills/our-skill/SKILL.md"))).to eq("app skill\n")
    end
  end
end
