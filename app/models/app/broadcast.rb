module App::Broadcast
  extend ActiveSupport::Concern
  include ActionView::RecordIdentifier

  included do
    after_update_commit do
      broadcast_replace_later_to(
        self,
        target: dom_id(self, :header),
        partial: "projects/apps/header",
        locals: {app: self}
      )
    end
  end
end
