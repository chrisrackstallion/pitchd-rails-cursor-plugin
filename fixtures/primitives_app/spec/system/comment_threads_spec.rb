# Fixture, not a spec of this repo — excluded from the suite in .rspec.
RSpec.describe "Comment threads", type: :system do
  it "lets a reader reply to a comment", intent: "comment_threads#I1" do
  end

  # The group stays untagged: tags name the example that proves the clause, so
  # deleting that example takes the proof with it. One example may carry several
  # clauses, on its own continuation line when the name runs long.
  describe "nesting" do
    it "shows replies under their parent at any depth",
       intent: %w[comment_threads#I2 comment_threads#I4] do
    end
  end
end
