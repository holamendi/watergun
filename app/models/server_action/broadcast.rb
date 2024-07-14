module ServerAction::Broadcast
  extend ActiveSupport::Concern
  include ActionView::RecordIdentifier

  included do
    broadcasts_to ->(server_action) { [server_action.account, :server_actions] },
      partial: "server_actions/server_action",
      inserts_by: :prepend
  end
end
