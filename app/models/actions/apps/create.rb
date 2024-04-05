module Actions
  module Apps
    class Create < Action
      store_attribute :payload, :dokku_id, :string

      validates :dokku_id, presence: true

      def self.processor
        Processors::Apps::Create
      end
    end
  end
end
