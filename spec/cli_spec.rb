# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "open3"

RSpec.describe AgentHarnessRails::CLI do
  def run(*argv)
    out = StringIO.new
    err = StringIO.new
    status = described_class.new(argv, out: out, err: err).run
    [ status, out.string, err.string ]
  end

  describe "help" do
    # -h and --help are how scripts and CI ask for usage, so they must succeed
    # and print to stdout.
    [ "-h", "--help", "help" ].each do |invocation|
      it "prints usage to stdout and exits 0 for #{invocation}" do
        status, out, err = run(invocation)

        expect(status).to eq(0)
        expect(out).to include("usage: agent_harness_rails")
        expect(err).to be_empty
      end
    end

    it "wins over a command, so `install --help` explains instead of installing" do
      status, out, = run("install", "--help", "--path", project)

      expect(status).to eq(0)
      expect(out).to include("usage: agent_harness_rails")
      expect(Dir.children(project)).to be_empty
    end
  end

  describe "errors" do
    it "prints usage to stderr and exits 1 with no command" do
      status, out, err = run

      expect(status).to eq(1)
      expect(out).to be_empty
      expect(err).to include("usage: agent_harness_rails")
    end

    it "names an unknown command before the usage" do
      status, _, err = run("instal")

      expect(status).to eq(1)
      expect(err).to include("unknown command: instal")
    end

    it "reports an unknown option without a backtrace" do
      status, _, err = run("install", "--frobnicate")

      expect(status).to eq(1)
      expect(err).to include("error: invalid option: --frobnicate")
    end

    it "rejects a stray argument instead of ignoring it" do
      status, _, err = run("install", "extra", "--path", project)

      expect(status).to eq(1)
      expect(err).to include("unexpected argument: extra")
      expect(Dir.children(project)).to be_empty
    end
  end

  it "prints the version" do
    status, out, = run("version")

    expect(status).to eq(0)
    expect(out.strip).to eq(AgentHarnessRails::VERSION)
  end

  # The trap only exists in link mode: git refuses a pathspec beyond a symlink, so
  # a skill authored through .cursor/skills/ writes fine and then fails to commit.
  # Copy mode has no links and must stay quiet.
  it "tells link-mode installs where to author new files, and copy-mode installs nothing" do
    _, linked, = run("install", "--path", project)
    expect(linked).to include("author new skills, rules, and agents under agent_harness_rails/")

    _, copied, = run("install", "--path", project, "--mode", "copy")
    expect(copied).not_to include("author new skills")
  end

  # A migration leaves deletions at paths that now sit under a link, so they cannot
  # be staged by name at all — the reason to say `git add -A` only when files moved.
  it "names the bulk-staging command only when the install migrated files" do
    FileUtils.mkdir_p(File.join(project, ".cursor/skills/app-skill"))
    File.write(File.join(project, ".cursor/skills/app-skill/SKILL.md"), "# app skill\n")

    _, migrated, = run("install", "--path", project)
    expect(migrated).to include("commit this install with `git add -A`")

    _, again, = run("install", "--path", project)
    expect(again).not_to include("git add -A")
  end

  # Guard is advisory by construction: a non-zero exit would make every notice a
  # gate, and the checks in it each have an innocent cause as well as a
  # suspicious one.
  describe "guard" do
    def primitives_repo
      Open3.capture3("git", "-C", project, "init", "--quiet")
      Open3.capture3("git", "-C", project, "config", "user.email", "spec@example.test")
      Open3.capture3("git", "-C", project, "config", "user.name", "Spec")
      FileUtils.mkdir_p(File.join(project, "docs/primitives/capabilities"))
      File.write(File.join(project, "docs/primitives/capabilities/comment_threads.md"), <<~DOC)
        ---
        status: built
        intent:
          - id: I1
            clause: A reader can reply to any comment.
        ---
        # Comment threads
      DOC
      Open3.capture3("git", "-C", project, "add", "-A")
      Open3.capture3("git", "-C", project, "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "base")
    end

    it "exits 0 and prints the notices when the record changed" do
      primitives_repo
      File.write(File.join(project, "docs/primitives/capabilities/comment_threads.md"), <<~DOC)
        ---
        status: built
        intent:
          - id: I1
            clause: A signed-in reader can reply to any comment.
        ---
        # Comment threads
      DOC

      status, out, err = run("guard", "--path", project)

      expect(status).to eq(0)
      expect(out).to include("[intent/rewritten]").and include("1 notice for review")
      expect(err).to be_empty
    end

    it "exits 0 and says so when nothing moved" do
      primitives_repo

      status, out, = run("guard", "--path", project)

      expect(status).to eq(0)
      expect(out).to include("no change to intent or the specs that prove it")
    end

    it "reports as JSON for a hook to read" do
      primitives_repo

      status, out, = run("guard", "--path", project, "--format", "json")

      expect(status).to eq(0)
      expect(JSON.parse(out)).to include("notices" => 0, "capabilities" => 1)
    end

    # The one case that is a failure rather than a notice: the comparison could
    # not be made at all.
    it "exits 1 when there is no revision to compare against" do
      FileUtils.mkdir_p(File.join(project, "docs/primitives/capabilities"))
      File.write(File.join(project, "docs/primitives/capabilities/comment_threads.md"), "---\nstatus: built\nintent:\n  - id: I1\n    clause: A reader can reply.\n---\n")

      status, _, err = run("guard", "--path", project)

      expect(status).to eq(1)
      expect(err).to include("not a git repository")
    end

    it "rejects a format it cannot print" do
      status, _, err = run("guard", "--path", project, "--format", "xml")

      expect(status).to eq(1)
      expect(err).to include("format must be text or json")
    end
  end

  it "installs and checks a project end to end" do
    status, out, = run("install", "--path", project)
    expect(status).to eq(0)
    expect(out).to include("installed")

    status, out, = run("check", "--path", project)
    expect(status).to eq(0)
    expect(out).to include("matches this gem")
  end
end
