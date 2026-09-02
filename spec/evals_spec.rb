# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "agent_harness_rails/evals"

# Builds primitives trees in the per-example tmpdir spec_helper provides.
module EvalsHelpers
  def capability(name, body)
    write "docs/primitives/capabilities/#{name}.md", body
  end

  def spec_file(relative, body)
    write relative, body
  end

  def write(relative, body)
    path = File.join(project, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    path
  end

  def evals
    AgentHarnessRails::Evals.run(root: project)
  end

  def codes
    evals.findings.map(&:code)
  end

  # A doc where every active clause is proven, used as the baseline the negative
  # cases each break in one way.
  def proven_tree
    capability "comment_threads", <<~DOC
      ---
      status: built
      intent:
        - id: I1
          clause: A reader can reply to any comment.
          evaluations:
            - spec/system/comment_threads_spec.rb
      ---
      # Comment threads

      ## Provenance

      - 2026-08-07 — built: docs/plans/2026-08-05-comment-threads.md.
    DOC

    spec_file "spec/system/comment_threads_spec.rb", <<~SPEC
      RSpec.describe "Comment threads", type: :system do
        it "lets a reader reply", intent: "comment_threads#I1" do
        end
      end
    SPEC
  end
end

RSpec.configure { |config| config.include EvalsHelpers }

RSpec.describe AgentHarnessRails::Evals do
  it "passes when every active clause is proven by a tagged example" do
    proven_tree

    result = evals

    expect(result).to be_ok
    expect(result.findings).to be_empty
    expect(result.capabilities).to eq(1)
    expect(result.clauses).to eq(1)
  end

  it "fails a built clause that names no evaluation" do
    capability "comment_threads", <<~DOC
      ---
      status: built
      intent:
        - id: I1
          clause: A reader can reply to any comment.
      ---
      # Comment threads

      ## Provenance

      - 2026-08-07 — built: a plan.
    DOC

    expect(codes).to eq([ "clause/unproven" ])
    expect(evals.findings.first.line).to eq(4), "the offence should point at the clause, not the file"
  end

  it "fails an evaluation whose spec file does not exist" do
    proven_tree
    FileUtils.rm(File.join(project, "spec/system/comment_threads_spec.rb"))

    expect(codes).to include("evaluation/missing-file")
  end

  it "fails an evaluation whose spec file carries no matching tag" do
    proven_tree
    spec_file "spec/system/comment_threads_spec.rb", <<~SPEC
      RSpec.describe "Comment threads", type: :system do
        it "lets a reader reply" do
        end
      end
    SPEC

    expect(codes).to eq([ "evaluation/untagged" ])
  end

  it "fails a tag naming a capability that does not exist" do
    proven_tree
    spec_file "spec/system/billing_spec.rb", <<~SPEC
      RSpec.describe "Billing" do
        it "bills", intent: "billing#I1" do
        end
      end
    SPEC

    expect(codes).to eq([ "tag/unresolved" ])
  end

  it "fails a tag naming a superseded clause" do
    capability "comment_threads", <<~DOC
      ---
      status: built
      intent:
        - id: I1
          clause: Threads never nest deeper than 3 levels.
          superseded_by: [ I2 ]
          superseded_on: 2026-09-18
        - id: I2
          clause: A reader can reply at any depth.
          evaluations:
            - spec/system/comment_threads_spec.rb
      ---
      # Comment threads

      ## Provenance

      - 2026-09-19 — amended: I1 superseded by I2.
    DOC

    spec_file "spec/system/comment_threads_spec.rb", <<~SPEC
      RSpec.describe "Comment threads" do
        it "caps depth", intent: "comment_threads#I1" do
        end

        it "replies at any depth", intent: "comment_threads#I2" do
        end
      end
    SPEC

    expect(codes).to eq([ "tag/unresolved" ])
  end

  it "fails a tagged spec file the clause does not list" do
    proven_tree
    spec_file "spec/requests/comments_spec.rb", <<~SPEC
      RSpec.describe "Comments" do
        it "replies", intent: "comment_threads#I1" do
        end
      end
    SPEC

    expect(codes).to eq([ "tag/undeclared" ])
  end

  it "fails a malformed tag value" do
    proven_tree
    spec_file "spec/requests/comments_spec.rb", <<~SPEC
      RSpec.describe "Comments" do
        it "replies", intent: "comment_threads" do
        end
      end
    SPEC

    expect(codes).to eq([ "tag/malformed" ])
  end

  it "reads a %w list of tags on one example" do
    capability "billing", <<~DOC
      ---
      status: built
      intent:
        - id: I1
          clause: An owner can change plan mid-cycle.
          evaluations:
            - spec/system/billing_spec.rb
        - id: I2
          clause: A proration line appears on the next invoice.
          evaluations:
            - spec/system/billing_spec.rb
      ---
      # Billing

      ## Provenance

      - 2026-08-07 — built: a plan.
    DOC

    spec_file "spec/system/billing_spec.rb", <<~SPEC
      RSpec.describe "Billing" do
        it "changes the plan and prorates", intent: %w[billing#I1 billing#I2] do
        end
      end
    SPEC

    expect(evals).to be_ok
  end

  # The tag still resolves — it names a live clause and the doc lists the file —
  # so the only thing wrong with it is where it sits, and that is the one thing
  # reported. Reporting it again as an untagged evaluation would describe one
  # mistake twice.
  it "fails a tag sitting on the group rather than the example" do
    capability "billing", <<~DOC
      ---
      status: built
      intent:
        - id: I1
          clause: An owner can change plan mid-cycle.
          evaluations:
            - spec/system/billing_spec.rb
      ---
      # Billing

      ## Provenance

      - 2026-08-07 — built: a plan.
    DOC

    spec_file "spec/system/billing_spec.rb", <<~SPEC
      RSpec.describe "Billing" do
        describe "plan changes", intent: "billing#I1" do
          it "changes the plan" do
          end
        end
      end
    SPEC

    expect(codes).to eq([ "tag/misplaced" ])
  end

  it "accepts a tag whose metadata wraps onto its own line" do
    capability "billing", <<~DOC
      ---
      status: built
      intent:
        - id: I1
          clause: An owner can change plan mid-cycle.
          evaluations:
            - spec/system/billing_spec.rb
      ---
      # Billing

      ## Provenance

      - 2026-08-07 — built: a plan.
    DOC

    spec_file "spec/system/billing_spec.rb", <<~SPEC
      RSpec.describe "Billing" do
        it "changes the plan mid-cycle and prorates the difference",
           intent: "billing#I1" do
        end
      end
    SPEC

    expect(evals).to be_ok
  end

  describe "docs not yet built" do
    it "exempts a planned doc from coverage" do
      capability "onboarding", <<~DOC
        ---
        status: planned
        intent:
          - id: I1
            clause: A new account lands on a setup checklist.
        ---
        # Onboarding

        ## Provenance

        - 2026-08-17 — planned: a plan.
      DOC

      expect(evals).to be_ok
    end

    it "warns rather than fails when a built doc is mid-amendment" do
      capability "comment_threads", <<~DOC
        ---
        status: built
        intent:
          - id: I1
            clause: A reader can reply at any depth.
        ---
        # Comment threads

        ## Provenance

        - 2026-08-07 — built: the first plan.
        - 2026-09-18 — planned: the amendment plan.
      DOC

      result = evals

      expect(result).to be_ok
      expect(result.findings.map(&:code)).to eq([ "clause/in-flight" ])
    end

    # `unproven: true` used to buy a clause a warning instead of a failure. It
    # was the one way a built capability could stay green with nothing proving
    # it, which made it the one thing a backfill reached for. The key is gone:
    # a built clause names a spec or the run is red.
    it "fails a built clause with no evaluation, however it is annotated" do
      capability "comment_threads", <<~DOC
        ---
        status: built
        intent:
          - id: I1
            clause: A reader can reply at any depth.
            unproven: true
        ---
        # Comment threads

        ## Provenance

        - 2026-10-02 — backfilled from existing behaviour; prior history in git.
      DOC

      expect(codes).to eq([ "clause/unproven" ])
    end
  end

  describe "document structure" do
    it "fails a doc still using the retired prose sections" do
      capability "old", <<~DOC
        ---
        status: built
        ---
        # Old

        ## Intent

        - **I1** — A thing must be true.

        ## Evaluations

        | Clause | Proven at |
        |--------|-----------|
        | I1 | spec/system/old_spec.rb |
      DOC

      expect(codes).to eq([ "doc/legacy-format" ])
    end

    it "fails a doc carrying the retired specs: frontmatter key" do
      capability "old", <<~DOC
        ---
        status: built
        specs:
          - spec/system/old_spec.rb
        intent:
          - id: I1
            clause: A thing must be true.
        ---
        # Old
      DOC

      expect(codes).to eq([ "doc/legacy-format" ])
    end

    it "fails duplicated clause ids" do
      capability "comment_threads", <<~DOC
        ---
        status: shaping
        intent:
          - id: I1
            clause: A reader can reply.
          - id: I1
            clause: A reader can edit.
        ---
        # Comment threads
      DOC

      expect(codes).to eq([ "clause/duplicate-id" ])
    end

    it "fails a supersession pointing at a clause the doc does not define" do
      capability "comment_threads", <<~DOC
        ---
        status: shaping
        intent:
          - id: I1
            clause: A reader can reply.
            superseded_by: [ I9 ]
        ---
        # Comment threads
      DOC

      expect(codes).to eq([ "clause/dangling-supersession" ])
    end

    it "fails an unparseable frontmatter block" do
      capability "broken", <<~DOC
        ---
        status: built
        intent:
          - id: I1
           clause: badly indented
        ---
        # Broken
      DOC

      expect(codes).to eq([ "doc/malformed" ])
    end

    # The failure this replaces was silent: `Capability.load_all` globs one level
    # deep, so a nested doc's clauses did not exist as far as the tool was
    # concerned and the run stayed green over the gap.
    it "fails a capability doc nested in a subdirectory" do
      proven_tree
      capability "billing/plans", <<~DOC
        ---
        status: built
        intent:
          - id: I1
            clause: An owner can change plan mid-cycle.
        ---
        # Plans
      DOC

      expect(codes).to eq([ "doc/nested" ])
    end

    it "fails a doc with no frontmatter at all" do
      capability "bare", "# Bare\n\nJust prose.\n"

      expect(codes).to eq([ "doc/malformed" ])
    end

    it "keeps checking the rest of the tree when one doc is broken" do
      proven_tree
      capability "bare", "# Bare\n"

      expect(codes).to eq([ "doc/malformed" ])
    end
  end

  it "raises when there is no primitives tree to check" do
    expect { evals }.to raise_error(AgentHarnessRails::Error, %r{docs/primitives/capabilities})
  end
end

RSpec.describe AgentHarnessRails::CLI, "evals" do
  def run(*argv)
    out = StringIO.new
    err = StringIO.new
    code = described_class.new([ "evals", "--path", project, *argv ], out: out, err: err).run
    [ code, out.string, err.string ]
  end

  it "exits 0 and summarises a clean tree" do
    proven_tree

    code, out, = run

    expect(code).to eq(0)
    expect(out).to include("1 capability, 1 clause — no offences")
  end

  it "exits 1 and prints one line per offence" do
    proven_tree
    FileUtils.rm(File.join(project, "spec/system/comment_threads_spec.rb"))

    code, out, = run

    expect(code).to eq(1)
    expect(out).to include("docs/primitives/capabilities/comment_threads.md")
      .and include("4:1   E  ").and include("[evaluation/missing-file]")
  end

  it "reports the mid-amendment warning in the summary without failing" do
    capability "comment_threads", <<~DOC
      ---
      status: built
      intent:
        - id: I1
          clause: A reader can reply at any depth.
      ---
      # Comment threads

      ## Provenance

      - 2026-08-07 — built: the first plan.
      - 2026-09-18 — planned: the amendment plan.
    DOC

    code, out, = run

    expect(code).to eq(0)
    expect(out).to include("1 warning")
  end

  it "emits machine-readable findings with --format json" do
    proven_tree
    FileUtils.rm(File.join(project, "spec/system/comment_threads_spec.rb"))

    code, out, = run("--format", "json")
    payload = JSON.parse(out)

    expect(code).to eq(1)
    expect(payload["errors"]).to eq(1)
    expect(payload["findings"].first).to include("code" => "evaluation/missing-file")
  end

  it "reports a missing tree as an error rather than crashing" do
    code, _, err = run

    expect(code).to eq(1)
    expect(err).to start_with("error: no capability docs")
  end

  it "rejects an unknown format instead of silently falling back to text" do
    code, _, err = run("--format", "jsonn")

    expect(code).to eq(1)
    expect(err).to include("format must be text or json")
  end
end
