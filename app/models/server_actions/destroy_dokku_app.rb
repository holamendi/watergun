module ServerActions
  class DestroyDokkuApp < ServerAction
    alias_method :app, :actionable

    store_attribute :payload, :dokku_app_id, :string

    validates :dokku_app_id, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
    end

    def perform
      ssh_session { |ssh| Dokku::Apps::Destroy.call(ssh, app: dokku_app_id) }
    end
  end
end
