module Publishable
  extend ActiveSupport::Concern

  included do
    has_one :publication, dependent: :destroy
    after_save :notify_later
  end

  def publish(by:)
    create_publication!(publisher: by)
  end

  def published?
    publication.present?
  end
end
