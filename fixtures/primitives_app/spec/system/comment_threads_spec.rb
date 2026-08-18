# Fixture, not a spec of this repo — excluded from the suite in .rspec.
RSpec.describe "Comment threads", type: :system do
  it "lets a reader reply to a comment", intent: "comment_threads#I1" do
  end

  describe "nesting", intent: %w[comment_threads#I2 comment_threads#I4] do
    it "shows replies under their parent" do
    end
  end
end
