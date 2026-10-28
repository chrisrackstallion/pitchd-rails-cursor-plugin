# frozen_string_literal: true

require "spec_helper"
require "open3"
require "agent_harness_rails/guard"

# Every example builds a real git repository in the tmpdir spec_helper provides:
# the baseline is a commit, the change under test is the working tree.
RSpec.describe AgentHarnessRails::Guard do
  def git(*args)
    out, err, status = Open3.capture3("git", "-C", project, *args)
    raise "git #{args.join(' ')} failed: #{err}" unless status.success?

    out
  end

  def repo
    git "init", "--quiet"
    git "config", "user.email", "spec@example.test"
    git "config", "user.name", "Spec"
    git "config", "commit.gpgsign", "false"
  end

  def commit(message = "baseline")
    git "add", "-A"
    git "commit", "--quiet", "--message", message
  end

  def write(relative, body)
    path = File.join(project, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    path
  end

  def capability(body, name: "comment_threads")
    write "docs/primitives/capabilities/#{name}.md", body
  end

  def guard(base: "HEAD")
    described_class.run(root: project, base: base)
  end

  def codes(base: "HEAD")
    guard(base: base).findings.map(&:code)
  end

  def message_for(code)
    guard.findings.find { |finding| finding.code == code }&.message.to_s
  end

  # One built capability, one active clause, one tagged example proving it —
  # committed. Each example then breaks exactly one thing about it.
  def committed_baseline(status: "built", clause: "A reader can reply to any comment.")
    repo
    capability <<~DOC
      ---
      status: #{status}
      intent:
        - id: I1
          clause: #{clause}
          evaluations:
            - spec/system/comment_threads_spec.rb
      ---
      # Comment threads

      ## Shape

      - Replies are `Comment` records with a `parent_id`.

      ## Provenance

      - 2026-08-07 — built: docs/plans/2026-08-05-comment-threads.md.
    DOC

    write "spec/system/comment_threads_spec.rb", <<~SPEC
      RSpec.describe "Comment threads", type: :system do
        it "lets a reader reply", intent: "comment_threads#I1" do
          visit post_path(post)
          expect(page).to have_content("Replied")
        end
      end
    SPEC

    commit
  end

  # Rewrites the whole doc; every example that changes intent goes through here
  # so the diff under test is the frontmatter and nothing else.
  def rewrite_capability(intent:, status: "built", provenance: [ "2026-08-07 — built: docs/plans/2026-08-05-comment-threads.md." ])
    capability <<~DOC
      ---
      status: #{status}
      intent:
      #{intent.chomp.gsub(/^/, '  ')}
      ---
      # Comment threads

      ## Shape

      - Replies are `Comment` records with a `parent_id`.

      ## Provenance

      #{provenance.map { |line| "- #{line}" }.join("\n")}
    DOC
  end

  describe "a change that leaves the record alone" do
    it "reports nothing when nothing moved" do
      committed_baseline

      result = guard

      expect(result).to be_clean
      expect(result.capabilities).to eq(1)
    end

    it "stays silent while the record grows" do
      committed_baseline
      rewrite_capability(
        intent: <<~YAML,
          - id: I1
            clause: A reader can reply to any comment.
            evaluations:
              - spec/system/comment_threads_spec.rb
          - id: I2
            clause: A reader can delete their own comment.
            evaluations:
              - spec/system/comment_threads_spec.rb
        YAML
        provenance: [ "2026-08-07 — built: docs/plans/2026-08-05-comment-threads.md.",
                      "2026-09-01 — amended: I2 added." ]
      )
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it "lets a reader reply", intent: "comment_threads#I1" do
            visit post_path(post)
            expect(page).to have_content("Replied")
          end

          it "lets a reader delete", intent: "comment_threads#I2" do
            expect(page).to have_content("Deleted")
          end
        end
      SPEC

      expect(codes).to be_empty
    end

    # The invariant the whole tool is sold on. Pairing examples by position
    # inside a file would break it for every insertion above an existing one.
    it "stays silent when a new tagged example is inserted above an untouched one" do
      committed_baseline
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it "lets a subscriber reply", intent: "comment_threads#I1" do
            expect(page).to have_content("Subscribed")
          end

          it "lets a reader reply", intent: "comment_threads#I1" do
            visit post_path(post)
            expect(page).to have_content("Replied")
          end
        end
      SPEC

      expect(codes).to be_empty
    end

    it "has nothing to compare when the tree is new on this branch" do
      repo
      write "README.md", "an app with no primitives yet\n"
      commit
      capability <<~DOC
        ---
        status: shaping
        intent:
          - id: I1
            clause: A reader can reply to any comment.
        ---
        # Comment threads

        ## Provenance

        - 2026-08-07 — shaped: a brainstorm.
      DOC

      expect(codes).to be_empty
    end
  end

  describe "intent" do
    it "notices a clause reworded in place under the same id" do
      committed_baseline
      rewrite_capability(intent: <<~YAML)
        - id: I1
          clause: A signed-in reader can reply to any comment.
          evaluations:
            - spec/system/comment_threads_spec.rb
      YAML

      expect(codes).to eq([ "intent/rewritten" ])

      finding = guard.findings.find { |candidate| candidate.code == "intent/rewritten" }
      expect(finding.details.map(&:text)).to include("A reader can reply to any comment.")
        .and include("A signed-in reader can reply to any comment.")
    end

    it "leaves an in-place edit alone while the doc is still shaping" do
      committed_baseline(status: "shaping")
      rewrite_capability(status: "shaping", intent: <<~YAML)
        - id: I1
          clause: A signed-in reader can reply to any comment.
          evaluations:
            - spec/system/comment_threads_spec.rb
      YAML

      expect(codes).to be_empty
    end

    # The discharge exists for the human who amended deliberately and wrote it
    # down; an agent reaching for it to quiet its own notice is the misuse the
    # skills warn about.
    it "is discharged by a new provenance entry naming the clause" do
      committed_baseline
      rewrite_capability(
        intent: <<~YAML,
          - id: I1
            clause: A signed-in reader can reply to any comment.
            evaluations:
              - spec/system/comment_threads_spec.rb
        YAML
        provenance: [ "2026-08-07 — built: docs/plans/2026-08-05-comment-threads.md.",
                      "2026-09-01 — amended: I1 narrowed to signed-in readers." ]
      )

      expect(codes).to be_empty
    end

    it "notices a clause deleted outright" do
      committed_baseline
      rewrite_capability(intent: <<~YAML)
        - id: I2
          clause: A reader can delete their own comment.
          evaluations:
            - spec/system/comment_threads_spec.rb
      YAML
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it "lets a reader delete", intent: "comment_threads#I2" do
            expect(page).to have_content("Deleted")
          end
        end
      SPEC

      expect(codes).to include("intent/vanished")
      expect(message_for("intent/vanished")).to include("superseded_by")
    end

    it "notices a supersession, and does not also report the proof it retired" do
      committed_baseline
      rewrite_capability(
        intent: <<~YAML,
          - id: I1
            clause: A reader can reply to any comment.
            superseded_by: [ I2 ]
            superseded_on: 2026-09-18
          - id: I2
            clause: A reader can reply at any depth.
            evaluations:
              - spec/system/comment_threads_spec.rb
        YAML
        provenance: [ "2026-08-07 — built: docs/plans/2026-08-05-comment-threads.md.",
                      "2026-09-18 — amended: I1 superseded by I2." ]
      )
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it "lets a reader reply at depth", intent: "comment_threads#I2" do
            expect(page).to have_content("Replied")
          end
        end
      SPEC

      expect(codes).to eq([ "intent/deactivated" ])
    end
  end

  describe "evaluations" do
    it "notices an active clause losing a proof" do
      committed_baseline
      rewrite_capability(intent: <<~YAML)
        - id: I1
          clause: A reader can reply to any comment.
      YAML

      expect(codes).to include("evaluation/dropped")
    end

    # Not a loss of coverage — the clause is proven somewhere else, and saying
    # it is "proven by less" would be false.
    it "separates a same-layer file swap from a dropped evaluation" do
      committed_baseline
      rewrite_capability(intent: <<~YAML)
        - id: I1
          clause: A reader can reply to any comment.
          evaluations:
            - spec/system/replies_spec.rb
      YAML
      write "spec/system/replies_spec.rb", <<~SPEC
        RSpec.describe "Replies", type: :system do
          it "lets a reader reply", intent: "comment_threads#I1" do
            expect(page).to have_content("Replied")
          end
        end
      SPEC

      expect(codes).to include("evaluation/moved")
      expect(codes).not_to include("evaluation/dropped", "evaluation/relayered")
    end

    it "notices proof moving to a layer that may not hold it" do
      committed_baseline
      rewrite_capability(intent: <<~YAML)
        - id: I1
          clause: A reader can reply to any comment.
          evaluations:
            - spec/models/comment_spec.rb
      YAML
      write "spec/models/comment_spec.rb", <<~SPEC
        RSpec.describe Comment do
          it "replies", intent: "comment_threads#I1" do
            expect(comment.replies).to be_present
          end
        end
      SPEC

      expect(codes).to include("evaluation/relayered")
      expect(codes).not_to include("evaluation/dropped")
    end
  end

  describe "proof" do
    it "notices a tagged example that is gone while its clause is still active" do
      committed_baseline
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
        end
      SPEC

      expect(codes).to include("proof/removed")
    end

    it "notices an example that kept its tag and lost its assertions" do
      committed_baseline
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it "lets a reader reply", intent: "comment_threads#I1" do
            visit post_path(post)
          end
        end
      SPEC

      expect(codes).to eq([ "proof/weakened" ])
    end

    it "notices an example whose body changed without losing assertions" do
      committed_baseline
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it "lets a reader reply", intent: "comment_threads#I1" do
            visit post_path(other_post)
            expect(page).to have_content("Replied")
          end
        end
      SPEC

      expect(codes).to eq([ "proof/changed" ])
    end

    # A `{ … }` example has no `end` of its own; delimiting it by indentation
    # alone runs the body on to some later example's `end`, so every sibling
    # added below reads as a change to it.
    it "does not read a brace-bodied example as changed when a sibling is added below it" do
      repo
      capability <<~DOC
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

        - 2026-08-07 — built: a plan.
      DOC
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it("lets a reader reply", intent: "comment_threads#I1") { expect(page).to have_content("Replied") }
        end
      SPEC
      commit

      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it("lets a reader reply", intent: "comment_threads#I1") { expect(page).to have_content("Replied") }

          it "does something unrelated" do
            expect(page).to have_content("Other")
          end
        end
      SPEC

      expect(codes).to be_empty
    end

    it "reports a removal and a weakening in the same file" do
      repo
      capability <<~DOC
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

        - 2026-08-07 — built: a plan.
      DOC
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it "lets a reader reply", intent: "comment_threads#I1" do
            expect(page).to have_content("Replied")
          end

          it "lets a reader reply at depth", intent: "comment_threads#I1" do
            expect(page).to have_css(".reply .reply")
            expect(page).to have_content("Nested")
          end
        end
      SPEC
      commit

      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          it "lets a reader reply at depth", intent: "comment_threads#I1" do
            expect(page).to have_css(".reply .reply")
          end
        end
      SPEC

      expect(codes).to contain_exactly("proof/removed", "proof/weakened")
    end

    it "ignores re-nesting that leaves the example itself untouched" do
      committed_baseline
      write "spec/system/comment_threads_spec.rb", <<~SPEC
        RSpec.describe "Comment threads", type: :system do
          context "when signed in" do
            it "lets a reader reply", intent: "comment_threads#I1" do
              visit post_path(post)
              expect(page).to have_content("Replied")
            end
          end
        end
      SPEC

      expect(codes).to be_empty
    end
  end

  describe "the record itself" do
    it "notices a capability doc that was deleted" do
      committed_baseline
      FileUtils.rm(File.join(project, "docs/primitives/capabilities/comment_threads.md"))
      FileUtils.mkdir_p(File.join(project, "docs/primitives/capabilities"))

      expect(codes).to include("doc/removed")
    end

    it "notices a status downgrade that drops a coverage obligation" do
      committed_baseline
      rewrite_capability(status: "deprecated", intent: <<~YAML)
        - id: I1
          clause: A reader can reply to any comment.
          evaluations:
            - spec/system/comment_threads_spec.rb
      YAML

      expect(codes).to eq([ "status/downgraded" ])
    end

    # The fallback rank for an unrecognised status has to sit *below* every
    # valid one: a typo sheds every obligation `built` carried, and ranking it
    # above `built` would report the most consequential edit as no change.
    it "notices a status replaced with one it does not recognise" do
      committed_baseline
      rewrite_capability(status: "wip", intent: <<~YAML)
        - id: I1
          clause: A reader can reply to any comment.
          evaluations:
            - spec/system/comment_threads_spec.rb
      YAML

      expect(codes).to eq([ "status/downgraded" ])
    end

    # Comparing an unparseable doc reports every clause as a deletion — a
    # cascade that describes one broken edit as a series of decisions.
    it "says a doc stopped parsing instead of reporting its clauses as deleted" do
      committed_baseline
      capability <<~DOC
        ---
        status: built
        intent:
          - id: I1
           clause: broken: yaml: here
        ---
        # Comment threads
      DOC

      expect(codes).to eq([ "doc/unreadable" ])
    end

    it "notices provenance entries reordered, and one of two identical entries deleted" do
      committed_baseline
      rewrite_capability(
        intent: <<~YAML,
          - id: I1
            clause: A reader can reply to any comment.
            evaluations:
              - spec/system/comment_threads_spec.rb
        YAML
        provenance: [ "2026-09-01 — amended: later work.",
                      "2026-08-07 — built: docs/plans/2026-08-05-comment-threads.md." ]
      )

      expect(codes).to eq([ "provenance/rewritten" ]),
                       "append-only means the old entries stay at the front, in order"
    end

    it "notices an edit to an existing provenance entry" do
      committed_baseline
      rewrite_capability(
        intent: <<~YAML,
          - id: I1
            clause: A reader can reply to any comment.
            evaluations:
              - spec/system/comment_threads_spec.rb
        YAML
        provenance: [ "2026-08-07 — built: some other plan." ]
      )

      expect(codes).to eq([ "provenance/rewritten" ])
    end
  end

  describe "the comparison point" do
    it "compares against the merge base, not the tip of the base branch" do
      committed_baseline
      trunk = git("rev-parse", "--abbrev-ref", "HEAD").strip
      git "checkout", "--quiet", "-b", "feature"
      rewrite_capability(intent: <<~YAML)
        - id: I1
          clause: A signed-in reader can reply to any comment.
          evaluations:
            - spec/system/comment_threads_spec.rb
      YAML
      commit "amend intent"

      expect(codes(base: "HEAD")).to be_empty, "the change is committed, so HEAD sees nothing"
      expect(codes(base: trunk)).to eq([ "intent/rewritten" ])
    end

    it "refuses a base that does not resolve" do
      committed_baseline

      expect { guard(base: "no-such-ref") }.to raise_error(AgentHarnessRails::Error, /cannot resolve/)
    end

    it "says so outside a git repository" do
      capability <<~DOC
        ---
        status: built
        intent:
          - id: I1
            clause: A reader can reply to any comment.
            evaluations:
              - spec/system/comment_threads_spec.rb
        ---
        # Comment threads
      DOC

      expect { guard }.to raise_error(AgentHarnessRails::Error, /not a git repository/)
    end
  end
end
