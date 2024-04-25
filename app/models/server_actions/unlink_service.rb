module ServerActions
  class UnlinkService < ServerAction
    alias_method :service_link, :actionable

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :service_id, :string

    validates :dokku_app_id, :service_id, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
      self.dokku_service_id ||= service.dokku_id
    end

    delegate :app, :service, to: :service_link

    def concurrency_key
      service
    end

    private

    def perform
      Dokku::Apps::UnlinkService.call(ssh, service: dokku_service_id, app: dokku_app_id)
    end
  end
end
