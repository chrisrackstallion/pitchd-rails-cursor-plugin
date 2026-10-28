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
        .and include("was:  A reader can reply to any comment.")
        .and include("now:  A signed-in reader can reply to any comment.")
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

  # Proofs is a lookup, not a check: the exit code is 0 whatever it finds, because
  # most examples in a spec file carry no tag by design and a tagged count is a
  # number to compare with the plan, not a verdict.
  describe "proofs" do
    def stages
      FileUtils.mkdir_p(File.join(project, "docs/primitives/capabilities"))
      File.write(File.join(project, "docs/primitives/capabilities/project_stages.md"), <<~DOC)
        ---
        status: built
        intent:
          - id: I3
            clause: Only a published stage accepts entries.
            evaluations:
              - spec/policies/long_list_policy_spec.rb
        ---
        # Project stages
      DOC
      FileUtils.mkdir_p(File.join(project, "spec/policies"))
      File.write(File.join(project, "spec/policies/long_list_policy_spec.rb"), <<~SPEC)
        RSpec.describe LongListPolicy do
          it "denies entry to a draft stage" do
            expect(policy).not_to permit_action(:accept_entry)
          end

          it "denies entry to an archived stage", intent: "project_stages#I3" do
            expect(policy).not_to permit_action(:accept_entry)
          end
        end
      SPEC
    end

    it "prints one line per clause under its capability and exits 0" do
      stages

      status, out, err = run("proofs", "--path", project)

      expect(status).to eq(0)
      expect(out).to include("project_stages (built)")
        .and include("I3  Only a published stage accepts entries.")
        .and include("1 tagged example")
      expect(err).to be_empty
    end

    it "shows each evaluation file with its tagged examples" do
      stages

      _, out, = run("proofs", "project_stages", "--path", project)

      expect(out).to include("spec/policies/long_list_policy_spec.rb — 1 tagged example")
        .and include("denies entry to an archived stage")
        .and include("1 assertion")
    end

    # The output that made a group tag look like a real, weak proof: the
    # `describe` line printed among the examples with no description and no
    # assertions, and nothing in the footer about it.
    it "names a tag sitting on a group instead of printing it as a proof" do
      stages
      File.write(File.join(project, "spec/policies/long_list_policy_spec.rb"), <<~SPEC)
        RSpec.describe LongListPolicy do
          describe "denials", intent: "project_stages#I3" do
            it "denies entry to a draft stage" do
              expect(policy).not_to permit_action(:accept_entry)
            end
          end
        end
      SPEC

      status, out, = run("proofs", "project_stages#I3", "--path", project)

      expect(status).to eq(0)
      expect(out).to include("spec/policies/long_list_policy_spec.rb — 0 tagged examples")
        .and include("tag proving nothing: spec/policies/long_list_policy_spec.rb:2 sits on `describe` — no example under it")
        .and include("1 tag in the suite is on a group rather than an example")
      expect(out).not_to include("(no description)")
    end

    it "counts each kind of unusable tag in one footer line" do
      stages
      FileUtils.mkdir_p(File.join(project, "spec/requests"))
      File.write(File.join(project, "spec/requests/stages_spec.rb"), <<~SPEC)
        RSpec.describe "Stages", type: :request do
          it "names no clause", intent: "project_stages#I9" do
            expect(response).to be_forbidden
          end

          it "carries half a tag", intent: "project_stages" do
            expect(response).to be_forbidden
          end
        end
      SPEC

      _, out, = run("proofs", "--path", project)

      expect(out).to include("2 tags in the suite are not usable proof — 1 naming no active clause, " \
                             "1 not in `<capability>#I<n>` form; `agent_harness_rails evals` reports each")
    end

    # A reader holding the plan already knows which example is missing from the
    # tagged list, so the text stays tagged-only at every scope — printed,
    # untagged examples drowned the report in any real spec file. JSON keeps
    # them for close-out steps and reviewers.
    it "keeps untagged examples out of the text and in the JSON" do
      stages

      _, one_clause, = run("proofs", "project_stages#I3", "--path", project)
      _, json, = run("proofs", "project_stages#I3", "--format", "json", "--path", project)

      expect(one_clause).not_to include("denies entry to a draft stage")
      untagged = JSON.parse(json).dig("proofs", 0, "files", 0, "untagged")
      expect(untagged.map { |example| example["description"] }).to include("denies entry to a draft stage")
    end

    it "reports as JSON for a reviewer or close-out step to read" do
      stages

      status, out, = run("proofs", "project_stages#I3", "--format", "json", "--path", project)

      expect(status).to eq(0)
      expect(JSON.parse(out))
        .to include("clauses" => 1, "tagged_examples" => 1, "detail" => "detail",
                    "unresolved_tags" => 0, "misplaced_tags" => 0, "malformed_tags" => 0)
    end

    it "names what a scope it cannot parse should look like" do
      stages

      status, _, err = run("proofs", "Project Stages", "--path", project)

      expect(status).to eq(1)
      expect(err).to include("reads `<capability>` or `<capability>#I<n>`")
    end

    it "still rejects a second positional argument" do
      status, _, err = run("proofs", "project_stages", "extra", "--path", project)

      expect(status).to eq(1)
      expect(err).to include("unexpected argument: extra")
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
