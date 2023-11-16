module BelongsToServer
  extend ActiveSupport::Concern

  included do
    belongs_to :server

    attribute :server_id, defaut: -> { Current.server&.id }
  end
end
