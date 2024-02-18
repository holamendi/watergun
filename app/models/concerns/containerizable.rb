module Containerizable
  extend ActiveSupport::Concern

  included do
    has_many :containers, as: :containerizable, dependent: :destroy
  end
end
