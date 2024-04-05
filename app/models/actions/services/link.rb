module Actions
  module Services
    class Link < Action
      store_attribute :payload, :service_link_id, :integer
      store_attribute :payload, :service_type, :string
      store_attribute :payload, :service_dokku_id, :string
      store_attribute :payload, :app_dokku_id, :string

      validates :service_dokku_id, :app_dokku_id, :service_type, :service_link_id, presence: true

      def self.processor
        Processors::Services::Link
      end
    end
  end
end
