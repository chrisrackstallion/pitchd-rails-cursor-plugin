RSpec.describe Account::Onboarding do
  it "completes" do
    described_class.new(Account.new).complete
  end
end
