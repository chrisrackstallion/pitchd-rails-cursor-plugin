class Article < ApplicationRecord
  include Publishable

  belongs_to :author, class_name: "User"

  def byline
    "by #{author.name}"
  end

  def legacy_slug
    title.parameterize
  end

  private
    def notify_later
      NotifySubscribersJob.perform_later(id)
    end
end
