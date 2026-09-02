RSpec.describe Article do
  it "publishes" do
    article = Article.new
    article.publish(by: nil)

    expect(article.published?).to be true

    NotifySubscribersJob.perform_now(article.id)
  end
end
