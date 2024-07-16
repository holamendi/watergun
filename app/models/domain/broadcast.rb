module Domain::Broadcast
  extend ActiveSupport::Concern

  included do
    broadcasts_to ->(domain) { [domain.app, :domains] },
      partial: "projects/apps/domains/domain",
      inserts_by: :prepend
  end
end
