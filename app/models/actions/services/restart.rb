module Actions
  module Services
    class Restart < Action
      store_attribute :payload, :dokku_id, :string
      store_attribute :payload, :service_type, :string

      validates :dokku_id, :service_type, presence: true

      def self.processor
        Processors::Services::Restart
      end
    end
  end
end
