module Service::Broadcast
  extend ActiveSupport::Concern
  include ActionView::RecordIdentifier

  included do
    broadcasts_refreshes
  end
end
