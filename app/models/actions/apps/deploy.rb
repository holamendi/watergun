module Actions
  module Apps
    class Deploy < Action
      store_attribute :payload, :dokku_id, :string

      validates :dokku_id, presence: true

      def self.processor
        Processors::Apps::Deploy
      end
    end
  end
end
