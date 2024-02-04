module DokkuEntity
  extend ActiveSupport::Concern

  included do
    before_validation :set_dokku_id, on: :create
  end

  private

  def set_dokku_id
    self.dokku_id = "#{name.parameterize}-#{SecureRandom.hex(2)}"
  end
end
