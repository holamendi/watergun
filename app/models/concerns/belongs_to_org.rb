module BelongsToOrg
  extend ActiveSupport::Concern

  included do
    belongs_to :org

    attribute :org_id, defaut: -> { Current.org&.id }
  end
end
