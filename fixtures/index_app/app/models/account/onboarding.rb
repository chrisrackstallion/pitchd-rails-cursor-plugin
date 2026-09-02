class Account::Onboarding
  def initialize(account)
    @account = account
  end

  def complete
    @account.update!(onboarded_at: Time.current)
  end
end
