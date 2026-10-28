# frozen_string_literal: true

require "spec_helper"

# The payload's authoring contract. Nothing else holds it: .rubocop.yml excludes
# agent_harness_rails/**/*, and malformed frontmatter does not fail — the skill
# or rule silently never loads, inside an agent, long after the edit.
RSpec.describe "payload authoring" do
  # Frontmatter is the only text an editor loads before a skill fires, and a long
  # one gets truncated. Well clear of every current description.
  let(:description_budget) { 1024 }

  def frontmatter(path)
    body = File.read(path, encoding: "UTF-8")

    YAML.safe_load(body[/\A---\n(.*?)\n---\n/m, 1].to_s) || {}
  end

  def payload_glob(pattern)
    Dir.glob(File.join(AgentHarnessRails.payload, pattern)).sort
  end

  describe "skills" do
    it "gives every skill directory a SKILL.md, and puts SKILL.md nowhere else" do
      directories = payload_glob("skills/*").select { |path| File.directory?(path) }
      expect(directories).not_to be_empty

      missing = directories.reject { |path| File.file?(File.join(path, "SKILL.md")) }
      expect(missing).to be_empty, "no SKILL.md in #{missing.join(", ")}"

      # Deeper than skills/<name>/SKILL.md is invisible to Claude Code, which
      # does not recurse. spec/installer_spec.rb makes the same demand of an
      # installed tree; this catches it before the copy.
      expect(payload_glob("skills/*/*/**/SKILL.md")).to be_empty
    end

    it "names each skill for its directory, so the path an agent reads is the name it invokes" do
      payload_glob("skills/*/SKILL.md").each do |path|
        expect(frontmatter(path)["name"]).to eq(File.basename(File.dirname(path))), path
      end
    end

    it "describes each skill within the budget an editor loads" do
      payload_glob("skills/*/SKILL.md").each do |path|
        description = frontmatter(path)["description"].to_s

        expect(description).not_to be_empty, path
        expect(description.length).to be <= description_budget, "#{path}: #{description.length} chars"
      end
    end
  end

  describe "rules" do
    it "carries the Cursor attachment frontmatter, scoping every rule but the contract by glob" do
      paths = payload_glob("rules/*.mdc")
      expect(paths).not_to be_empty

      paths.each do |path|
        rule = frontmatter(path)

        expect(rule["description"].to_s).not_to be_empty, path
        expect([ true, false ]).to include(rule["alwaysApply"]), "#{path}: alwaysApply must be a boolean"
        # An unscoped rule that does not always apply attaches nowhere.
        expect(rule["globs"].to_s).not_to be_empty, path unless rule["alwaysApply"]
      end
    end
  end

  describe "agents" do
    it "names each agent for its filename, because that is the name a parent delegates to" do
      paths = payload_glob("agents/*.md")
      expect(paths).not_to be_empty

      paths.each do |path|
        agent = frontmatter(path)

        expect(agent["name"]).to eq(File.basename(path, ".md")), path
        expect(agent["description"].to_s).not_to be_empty, path
      end
    end
  end
end
