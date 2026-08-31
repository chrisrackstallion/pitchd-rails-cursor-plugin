# frozen_string_literal: true

require "spec_helper"
require "open3"
require "agent_harness_rails/proof_report"

# The case this command exists for, in every example below: a clause the plan
# meant to prove with several examples in one file, where only some of them were
# tagged. `evals` passes that — one tag makes the file a carrier — so the numbers
# here are the only place it shows.
RSpec.describe AgentHarnessRails::ProofReport do
  def write(relative, body)
    path = File.join(project, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    path
  end

  def capability(body, name: "project_stages")
    write "docs/primitives/capabilities/#{name}.md", body
  end

  def report(scope: nil, since: nil)
    described_class.run(root: project, scope: scope, since: since)
  end

  def row(id, **)
    report(**).rows.find { |candidate| candidate.clause.id == id }
  end

  def file_of(id, **)
    row(id, **).files.first
  end

  # One built capability whose I3 is proven by a policy spec holding four denial
  # examples — three tagged, one not — plus an untagged example belonging to
  # another behaviour entirely.
  def stages(evaluations: [ "spec/policies/long_list_policy_spec.rb" ])
    capability <<~DOC
      ---
      status: built
      intent:
        - id: I3
          clause: Only a published stage accepts entries.
          evaluations:
      #{evaluations.map { |path| "      - #{path}" }.join("\n")}
      ---
      # Project stages
    DOC

    write "spec/policies/long_list_policy_spec.rb", <<~SPEC
      RSpec.describe LongListPolicy do
        it "denies entry to a draft stage" do
          expect(policy).not_to permit_action(:accept_entry)
        end

        it "denies entry to an archived stage", intent: "project_stages#I3" do
          expect(policy).not_to permit_action(:accept_entry)
          expect(policy.reason).to eq(:archived)
        end

        it "denies entry past the cap", intent: "project_stages#I3" do
          expect(policy).not_to permit_action(:accept_entry)
        end

        it "denies entry to a locked stage", intent: "project_stages#I3" do
          expect(policy).not_to permit_action(:accept_entry)
        end

        it "lists published stages" do
          expect(scope).to eq([ published ])
        end
      end
    SPEC
  end

  it "counts how many of an evaluation file's examples carry the clause's tag" do
    stages

    expect(file_of("I3")).to have_attributes(examples: 5, path: "spec/policies/long_list_policy_spec.rb")
    expect(file_of("I3").tagged.size).to eq(3)
  end

  # The finding this whole command is for: the fourth denial, sitting beside
  # three tagged siblings, named in the plan and tagged by nobody.
  it "names the examples in that file carrying no intent tag" do
    stages

    expect(file_of("I3").untagged.map(&:description))
      .to eq([ "denies entry to a draft stage", "lists published stages" ])
  end

  it "reads the description of each tagged example, with its assertion count" do
    stages

    expect(file_of("I3").tagged.first)
      .to have_attributes(opener: 6, description: "denies entry to an archived stage", assertions: 2)
  end

  # An apostrophe inside a double-quoted name must not end the description half
  # way through — a reader is about to compare it with a line in the plan.
  it "keeps a description containing an apostrophe whole" do
    stages
    write "spec/policies/long_list_policy_spec.rb", <<~SPEC
      RSpec.describe LongListPolicy do
        it "denies a reader's entry", intent: "project_stages#I3" do
          expect(policy).not_to permit_action(:accept_entry)
        end
      end
    SPEC

    expect(file_of("I3").tagged.first.description).to eq("denies a reader's entry")
  end

  # Untagged means "carries no intent tag at all". An example proving a sibling
  # clause is not work this change forgot to do.
  it "leaves an example proving another clause out of the untagged list" do
    capability <<~DOC
      ---
      status: built
      intent:
        - id: I1
          clause: A member can move a project to any stage.
          evaluations:
            - spec/system/project_stages_spec.rb
        - id: I3
          clause: Only a published stage accepts entries.
          evaluations:
            - spec/system/project_stages_spec.rb
      ---
      # Project stages
    DOC
    write "spec/system/project_stages_spec.rb", <<~SPEC
      RSpec.describe "Project stages", type: :system do
        it "moves a project along", intent: "project_stages#I1" do
          expect(page).to have_content("In review")
        end

        it "refuses a draft stage", intent: "project_stages#I3" do
          expect(page).to have_content("not published")
        end

        it "shows the board" do
          expect(page).to have_content("Board")
        end
      end
    SPEC

    expect(file_of("I3").untagged.map(&:description)).to eq([ "shows the board" ])
  end

  it "reports a file the tags are in but the clause never declared" do
    stages(evaluations: [ "spec/requests/stages_spec.rb" ])
    write "spec/requests/stages_spec.rb", <<~SPEC
      RSpec.describe "Stages", type: :request do
        it "redirects a draft entry", intent: "project_stages#I3" do
          expect(response).to redirect_to(board_path)
        end
      end
    SPEC

    expect(row("I3").files.map { |file| [ file.path, file.declared ] })
      .to eq([ [ "spec/policies/long_list_policy_spec.rb", false ], [ "spec/requests/stages_spec.rb", true ] ])
  end

  it "reports a declared evaluation the app does not have" do
    stages(evaluations: [ "spec/policies/gone_spec.rb" ])

    expect(row("I3").files.map { |file| [ file.path, file.exists ] })
      .to include([ "spec/policies/gone_spec.rb", false ])
  end

  it "keeps a superseded clause's still-tagged example visible" do
    capability <<~DOC
      ---
      status: built
      intent:
        - id: I3
          clause: A stage holds at most 200 entries.
          superseded_by: [ I5 ]
          superseded_on: 2026-08-01
        - id: I5
          clause: A stage holds at most 500 entries.
          evaluations:
            - spec/policies/long_list_policy_spec.rb
      ---
      # Project stages
    DOC
    write "spec/policies/long_list_policy_spec.rb", <<~SPEC
      RSpec.describe LongListPolicy do
        it "caps a stage", intent: "project_stages#I3" do
          expect(policy).not_to permit_action(:accept_entry)
        end
      end
    SPEC

    expect(row("I3").tagged).to eq(1)
    expect(row("I3").state).to eq("superseded by I5")
  end

  # Counted, not listed: an unresolvable tag is `evals`' offence to report, and
  # saying it twice describes one mistake in two voices.
  it "counts tags naming no active clause without listing them" do
    stages
    write "spec/requests/stages_spec.rb", <<~SPEC
      RSpec.describe "Stages", type: :request do
        it "names a clause that does not exist", intent: "project_stages#I9" do
          expect(response).to be_forbidden
        end
      end
    SPEC

    expect(report.unusable).to include(unresolved: 1)
  end

  # A tag on a `describe` has no example under it, so reading it as a proof puts a
  # line with no description and no assertions among the real ones — which reads
  # as a weak proof rather than as the offence `evals` calls it.
  describe "a tag on a group rather than an example" do
    def grouped
      capability <<~DOC
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
      write "spec/policies/long_list_policy_spec.rb", <<~SPEC
        RSpec.describe LongListPolicy do
          describe "denials", intent: "project_stages#I3" do
            it "denies entry to a draft stage" do
              expect(policy).not_to permit_action(:accept_entry)
            end

            it "denies entry to an archived stage" do
              expect(policy).not_to permit_action(:accept_entry)
            end
          end
        end
      SPEC
    end

    it "keeps it out of the tagged count" do
      grouped

      expect(file_of("I3").tagged).to be_empty
      expect(file_of("I3").examples).to eq(2)
    end

    it "reports it as misplaced, with the group it sits on" do
      grouped

      expect(file_of("I3").misplaced.map { |proof| [ proof.line, proof.group ] }).to eq([ [ 2, "describe" ] ])
    end

    it "still shows both real examples as carrying no tag" do
      grouped

      expect(file_of("I3").untagged.map(&:description))
        .to eq([ "denies entry to a draft stage", "denies entry to an archived stage" ])
    end

    it "counts it, so the footer can say the suite holds a tag that proves nothing" do
      grouped

      expect(report.unusable).to eq(unresolved: 0, misplaced: 1, malformed: 0)
    end

    # One label per tag: a tag naming nothing real is unresolved even when it also
    # sits on a group, so the counts sum to the number of unusable tags.
    it "labels a misplaced tag naming no clause as unresolved only" do
      grouped
      write "spec/requests/stages_spec.rb", <<~SPEC
        RSpec.describe "Stages", type: :request do
          describe "denials", intent: "project_stages#I9" do
            it "redirects" do
              expect(response).to redirect_to(board_path)
            end
          end
        end
      SPEC

      expect(report.unusable).to eq(unresolved: 1, misplaced: 1, malformed: 0)
    end

    it "counts a tag that is not in `<capability>#I<n>` form" do
      grouped
      write "spec/requests/stages_spec.rb", <<~SPEC
        RSpec.describe "Stages", type: :request do
          it "carries half a tag", intent: "project_stages" do
            expect(response).to redirect_to(board_path)
          end
        end
      SPEC

      expect(report.unusable).to include(malformed: 1)
    end
  end

  describe "scope" do
    it "narrows to one capability" do
      stages
      capability "---\nstatus: built\nintent:\n  - id: I1\n    clause: A reader can reply.\n---\n", name: "comment_threads"

      expect(report(scope: "project_stages").rows.map(&:capability).uniq).to eq([ "project_stages" ])
    end

    # A named scope earns the per-file example listings; unscoped stays at the
    # one-line-per-clause density a whole tree needs.
    it "reports detail for a named scope and summary for the whole tree" do
      stages

      expect(report(scope: "project_stages#I3").detail).to eq(:detail)
      expect(report(scope: "project_stages").detail).to eq(:detail)
      expect(report.detail).to eq(:summary)
    end

    it "raises rather than reporting nothing when the scope names no clause" do
      stages

      expect { report(scope: "project_stages#I9") }.to raise_error(AgentHarnessRails::Error, /nothing named/)
    end

    it "raises on a scope that is not a capability or a clause" do
      stages

      expect { report(scope: "Project Stages") }.to raise_error(AgentHarnessRails::Error, /reads/)
    end
  end

  # `--since` is the shape a task's verify step runs, so it must see a spec file
  # the change has only just created and never committed.
  describe "since a revision" do
    def git(*args)
      out, err, status = Open3.capture3("git", "-C", project, *args)
      raise "git #{args.join(' ')} failed: #{err}" unless status.success?

      out
    end

    def committed_stages
      stages(evaluations: [ "spec/policies/long_list_policy_spec.rb", "spec/system/project_stages_spec.rb" ])
      write "spec/system/project_stages_spec.rb", <<~SPEC
        RSpec.describe "Project stages", type: :system do
          it "moves a project along", intent: "project_stages#I3" do
            expect(page).to have_content("In review")
          end
        end
      SPEC
      git "init", "--quiet"
      git "config", "user.email", "spec@example.test"
      git "config", "user.name", "Spec"
      git "add", "-A"
      git "-c", "commit.gpgsign=false", "commit", "--quiet", "--message", "base"
    end

    it "reports nothing when no spec proving a clause has moved" do
      committed_stages

      expect(report(since: "HEAD").rows).to be_empty
    end

    it "selects the clause whose committed spec this change edited" do
      committed_stages
      write "spec/policies/long_list_policy_spec.rb", File.read(File.join(project, "spec/policies/long_list_policy_spec.rb")).sub("draft", "unpublished")

      expect(report(since: "HEAD").rows.map { |row| row.clause.id }).to eq([ "I3" ])
    end

    it "selects a clause proven only by a spec file this change has not committed" do
      committed_stages
      File.delete(File.join(project, "spec/policies/long_list_policy_spec.rb"))
      git "add", "-A"
      git "-c", "commit.gpgsign=false", "commit", "--quiet", "--message", "drop"
      stages(evaluations: [ "spec/policies/long_list_policy_spec.rb" ])

      expect(report(since: "HEAD").rows.map { |row| row.clause.id }).to eq([ "I3" ])
    end

    it "resolves the base and reports it" do
      committed_stages

      expect(report(since: "HEAD").base).to eq(git("rev-parse", "HEAD").strip)
    end
  end

  it "raises when the app has no primitives tree" do
    expect { report }.to raise_error(AgentHarnessRails::Error, %r{no capability docs at docs/primitives/capabilities/})
  end
end
