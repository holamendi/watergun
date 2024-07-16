module Project::Broadcast
  extend ActiveSupport::Concern
  include ActionView::RecordIdentifier

  included do
    broadcasts_refreshes_to ->(project) { [project.account, :projects] }
  end
end
