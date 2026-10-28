class NotifySubscribersJob < ApplicationJob
  def perform(article_id)
    Article.find(article_id).notify_subscribers
  end
end
