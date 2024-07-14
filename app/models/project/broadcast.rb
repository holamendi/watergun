module Project::Broadcast
  extend ActiveSupport::Concern
  include ActionView::RecordIdentifier

  included do
    after_save_commit do
      broadcast_refresh_to(account, :projects)
    end
  end
end
