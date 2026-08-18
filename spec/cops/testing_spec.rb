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

RSpec.describe RuboCop::Cop::AgentHarnessRails::NegativeOnlySpec, :config do
  it "flags an example that only proves an absence" do
    expect_offense(<<~RUBY)
      it "does not show the excluded agency" do
      ^^ Every example needs at least one positive assertion — this one only proves an absence, so it passes even if the page is empty.
        expect(page).not_to have_link("New Excluded Agency")
      end
    RUBY
  end

  it "accepts not_to paired with a positive assertion" do
    # The rule's own example: the positive assertion carries the test, the
    # negative one confirms the removal.
    expect_no_offenses(<<~RUBY)
      it "deletes the article" do
        click_button "Delete"

        expect(page).to have_content("Article deleted.")
        expect(page).not_to have_content("To Delete")
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
