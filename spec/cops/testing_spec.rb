# frozen_string_literal: true

require "spec_helper"
require "cops/cop_helper"

RSpec.describe RuboCop::Cop::AgentHarnessRails::SpecSleep, :config do
  it "flags a sleep" do
    expect_offense(<<~RUBY)
      click_button "Publish"
      sleep 2
      ^^^^^^^ Do not `sleep` in a spec. Capybara matchers already wait; otherwise assert on the state you are waiting for.
    RUBY
  end

  it "leaves a sleep on an explicit receiver alone" do
    expect_no_offenses("clock.sleep(2)\n")
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::StubbedSubject, :config do
  it "flags allow_any_instance_of" do
    expect_offense(<<~RUBY)
      allow_any_instance_of(Article).to receive(:published?).and_return(true)
      ^^^^^^^^^^^^^^^^^^^^^ `allow_any_instance_of` stubs every instance in the process. Use a real record, or inject the dependency.
    RUBY
  end

  it "flags stubbing the subject under test" do
    expect_offense(<<~RUBY)
      allow(described_class).to receive(:new).and_return(double)
      ^^^^^^^^^^^^^^^^^^^^^^ Stubbing `described_class` tests the stub, not the subject. Exercise the real object.
    RUBY
  end

  it "accepts an ordinary assertion about described_class" do
    expect_no_offenses("expect(described_class).to eq(Article)\n")
  end

  it "accepts stubbing a genuine collaborator" do
    expect_no_offenses("allow(payment_gateway).to receive(:charge).and_return(true)\n")
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::ViewSpec, :config do
  it "flags a view-typed example group" do
    expect_offense(<<~RUBY)
      RSpec.describe "articles/show", type: :view do
                                      ^^^^^^^^^^^ View specs are never written. Test rendering through a request spec, where the assigns are the ones the app really builds.
      end
    RUBY
  end

  it "flags anything living under spec/views" do
    expect_offense(<<~RUBY, "spec/views/articles/show.html.erb_spec.rb")
      RSpec.describe "articles/show" do
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ spec/views/ holds view specs, which are never written. Move these to spec/requests/ and assert on `response.body`.
      end
    RUBY
  end

  it "accepts a request spec" do
    expect_no_offenses(<<~RUBY, "spec/requests/articles_spec.rb")
      RSpec.describe "Articles", type: :request do
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::UnanchoredAbsence, :config do
  let(:cop_config) do
    {
      "DocumentSubjects" => %w[page response last_response rendered],
      "DocumentMatchers" => %w[have_content have_link have_button have_http_status],
      "ActionMethods" => %w[visit get post patch click_on fill_in]
    }
  end

  it "flags an absence read off a page" do
    expect_offense(<<~RUBY)
      it "does not show the excluded agency" do
      ^^ This example asserts only absences, and what it looks at can be absent for reasons the example is not about — a redirect, a blank render, a 500 all pass. Anchor it with one assertion that goes red when the request breaks, and keep the `not_to`. An assertion that cannot fail is not an anchor.
        visit agencies_path

        expect(page).not_to have_link("New Excluded Agency")
      end
    RUBY
  end

  it "flags an absence read off a response body" do
    expect_offense(<<~RUBY)
      it "hides the edit link from a reader" do
      ^^ This example asserts only absences, and what it looks at can be absent for reasons the example is not about — a redirect, a blank render, a 500 all pass. Anchor it with one assertion that goes red when the request breaks, and keep the `not_to`. An assertion that cannot fail is not an anchor.
        get article_path(article)

        expect(response.body).not_to include("Edit article")
      end
    RUBY
  end

  it "flags a status the request is not supposed to return" do
    # Every status but 403 passes, including the 500 that means the app broke.
    expect_offense(<<~RUBY)
      it "does not forbid the author" do
      ^^ This example asserts only absences, and what it looks at can be absent for reasons the example is not about — a redirect, a blank render, a 500 all pass. Anchor it with one assertion that goes red when the request breaks, and keep the `not_to`. An assertion that cannot fail is not an anchor.
        get edit_article_path(article)

        expect(response).not_to have_http_status(:forbidden)
      end
    RUBY
  end

  it "flags an unchanged count behind a request" do
    # The block form: `post` is the machinery, and a 500 leaves the count alone
    # exactly as a correctly-refused request does.
    expect_offense(<<~RUBY)
      it "does not create the article" do
      ^^ This example asserts only absences, and what it looks at can be absent for reasons the example is not about — a redirect, a blank render, a 500 all pass. Anchor it with one assertion that goes red when the request breaks, and keep the `not_to`. An assertion that cannot fail is not an anchor.
        expect { post articles_path, params: { article: { title: "" } } }.not_to change(Article, :count)
      end
    RUBY
  end

  it "flags a reloaded record asserted only by what it is not" do
    expect_offense(<<~RUBY)
      it "does not promote the user" do
      ^^ This example asserts only absences, and what it looks at can be absent for reasons the example is not about — a redirect, a blank render, a 500 all pass. Anchor it with one assertion that goes red when the request breaks, and keep the `not_to`. An assertion that cannot fail is not an anchor.
        patch user_path(user), params: { user: { admin: true } }

        expect(user.reload).not_to be_admin
      end
    RUBY
  end

  it "accepts a policy denial, because the policy answered for itself" do
    # Nothing sits between the example and the verdict: a missing policy or a
    # missing method raises, so no unrelated failure can land on the passing side.
    expect_no_offenses(<<~RUBY)
      it "denies destroy to the account owner" do
        expect(policy).not_to permit(owner_context, account)
      end
    RUBY
  end

  it "accepts a predicate denial on a real record" do
    expect_no_offenses(<<~RUBY)
      it "leaves the article unpublished" do
        article = create(:article)

        expect(article).not_to be_published
      end
    RUBY
  end

  it "accepts a no-op proved by the absence of an exception" do
    expect_no_offenses(<<~RUBY)
      it "is a no-op when already open" do
        card = create(:card)

        expect { card.reopen }.not_to raise_error
      end
    RUBY
  end

  it "accepts a job that correctly enqueues nothing" do
    # `perform_now` runs the unit itself, and raises on the way past if it is
    # broken — the harness's own job-spec example, which must stay clean.
    expect_no_offenses(<<~RUBY)
      it "does nothing when the article is unpublished" do
        article = create(:article)

        expect {
          described_class.perform_now(article.id)
        }.not_to have_enqueued_mail
      end
    RUBY
  end

  it "accepts an anchored absence" do
    expect_no_offenses(<<~RUBY)
      it "does not offer deleting to a reader" do
        visit article_path(article)

        expect(page).to have_content(article.title)
        expect(page).not_to have_button("Delete")
      end
    RUBY
  end

  it "leaves an example with no expectations alone" do
    # An empty or pending example is a different problem, and not this cop's.
    expect_no_offenses(<<~RUBY)
      it "is pending" do
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::TautologicalAssertion, :config do
  it "flags the padding that gets added to satisfy the absence rule" do
    expect_offense(<<~RUBY)
      expect(policy).to be_a(described_class)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `expect(policy).to be_a(described_class)` cannot be turned red by any change to the application — it proves nothing, and it anchors nothing. Assert something the code could get wrong.
    RUBY
  end

  it "flags an assertion that the class under test exists" do
    expect_offense(<<~RUBY)
      expect(described_class).not_to be_nil
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `expect(described_class).not_to be_nil` cannot be turned red by any change to the application — it proves nothing, and it anchors nothing. Assert something the code could get wrong.
    RUBY
  end

  it "accepts a type assertion about something other than the class under test" do
    expect_no_offenses(<<~RUBY)
      expect(response.parsed_body).to be_a(Hash)
    RUBY
  end

  it "accepts an inheritance assertion, which a change can falsify" do
    expect_no_offenses(<<~RUBY)
      expect(described_class).to be < ApplicationPolicy
    RUBY
  end

  it "accepts the decision the policy made" do
    expect_no_offenses(<<~RUBY)
      expect(policy.destroy?).to be false
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::HttpStatusComparison, :config do
  it "flags a comparison standing in for a negative status assertion" do
    expect_offense(<<~RUBY)
      expect(response.status).to be < 403
                                 ^^^^^^^^ Assert the status, not a range around it: `have_http_status(:ok)`. A comparison also passes for every other status on its side of the number — if the behaviour is "not this status", write `not_to have_http_status(...)` with a positive assertion beside it.
    RUBY
  end

  it "flags a band of statuses" do
    expect_offense(<<~RUBY)
      expect(response.status).to be_between(200, 299)
                                 ^^^^^^^^^^^^^^^^^^^^ Assert the status, not a range around it: `have_http_status(:ok)`. A comparison also passes for every other status on its side of the number — if the behaviour is "not this status", write `not_to have_http_status(...)` with a positive assertion beside it.
    RUBY
  end

  it "flags the comparison wherever it is written, not just as a matcher" do
    expect_offense(<<~RUBY)
      expect(response.code.to_i < 400).to be true
             ^^^^^^^^^^^^^^^^^^^^^^^^ Assert the status, not a range around it: `have_http_status(:ok)`. A comparison also passes for every other status on its side of the number — if the behaviour is "not this status", write `not_to have_http_status(...)` with a positive assertion beside it.
    RUBY
  end

  it "flags a Capybara status the same way" do
    expect_offense(<<~RUBY)
      expect(page.status_code).to be >= 400
                                  ^^^^^^^^^ Assert the status, not a range around it: `have_http_status(:ok)`. A comparison also passes for every other status on its side of the number — if the behaviour is "not this status", write `not_to have_http_status(...)` with a positive assertion beside it.
    RUBY
  end

  it "accepts the status named exactly" do
    expect_no_offenses(<<~RUBY)
      expect(response).to have_http_status(:forbidden)
    RUBY
  end

  it "accepts a negative status assertion paired with a positive one" do
    expect_no_offenses(<<~RUBY)
      expect(response).to have_http_status(:ok)
      expect(response).not_to have_http_status(:forbidden)
    RUBY
  end

  it "leaves comparisons that have nothing to do with a status alone" do
    expect_no_offenses(<<~RUBY)
      expect(article.reload.version).to be > 1
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::IntentTag, :config do
  it "flags a tag with no clause" do
    expect_offense(<<~RUBY)
      it "replies", intent: "comment_threads" do
                            ^^^^^^^^^^^^^^^^^ Intent tags read `<capability>#I<n>`, naming a clause in docs/primitives/capabilities/ — for example `comment_threads#I2`.
      end
    RUBY
  end

  it "flags a clause id missing its I" do
    expect_offense(<<~RUBY)
      it "replies", intent: "comment_threads#2" do
                            ^^^^^^^^^^^^^^^^^^^ Intent tags read `<capability>#I<n>`, naming a clause in docs/primitives/capabilities/ — for example `comment_threads#I2`.
      end
    RUBY
  end

  it "flags a tag that is not a string" do
    expect_offense(<<~RUBY)
      it "replies", intent: :comment_threads do
                            ^^^^^^^^^^^^^^^^ Intent tags read `<capability>#I<n>`, naming a clause in docs/primitives/capabilities/ — for example `comment_threads#I2`.
      end
    RUBY
  end

  it "accepts a well-formed tag" do
    expect_no_offenses(<<~RUBY)
      it "replies", intent: "comment_threads#I2" do
      end
    RUBY
  end

  it "accepts a list of tags on one example" do
    expect_no_offenses(<<~RUBY)
      it "nests three deep", intent: %w[comment_threads#I2 comment_threads#I3] do
      end
    RUBY
  end

  it "flags a tag on a describe" do
    expect_offense(<<~RUBY)
      describe "threading", intent: "comment_threads#I2" do
      ^^^^^^^^ Tag the example that proves the clause, not `describe` — a group tag keeps resolving after the example it stood for is deleted.
      end
    RUBY
  end

  it "flags a tag on a context" do
    expect_offense(<<~RUBY)
      context "when nested", intent: %w[comment_threads#I2 comment_threads#I3] do
      ^^^^^^^ Tag the example that proves the clause, not `context` — a group tag keeps resolving after the example it stood for is deleted.
      end
    RUBY
  end

  it "flags a tag on RSpec.describe" do
    expect_offense(<<~RUBY)
      RSpec.describe "Comment threads", intent: "comment_threads#I2" do
            ^^^^^^^^ Tag the example that proves the clause, not `describe` — a group tag keeps resolving after the example it stood for is deleted.
      end
    RUBY
  end

  it "accepts a tag on any example alias" do
    expect_no_offenses(<<~RUBY)
      specify "replies", intent: "comment_threads#I2" do
      end

      scenario "replies", intent: "comment_threads#I2" do
      end
    RUBY
  end

  it "leaves an intent key in a hash literal alone" do
    # Not metadata: a hash in the body is a value the example builds, and the
    # placement rule has nothing to say about it.
    expect_no_offenses(<<~RUBY)
      let(:metadata) { { intent: "comment_threads#I2" } }
    RUBY
  end

  it "leaves an unrelated intent key alone" do
    # A hash key named `intent` in application code is not spec metadata; the
    # cop only runs over spec/ for exactly this reason.
    expect_no_offenses(<<~RUBY)
      it "records the reason", intent: "comment_threads#I1" do
        survey.update!(intent: params[:intent])
      end
    RUBY
  end
end
