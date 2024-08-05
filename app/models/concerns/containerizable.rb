module Containerizable
  extend ActiveSupport::Concern

  included do
    has_many :containers, as: :containerizable, dependent: :destroy
    has_many :container_checks, through: :containers
  end
end
