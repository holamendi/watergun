module Actions
  module Apps
    class Restart < Action
      store_attribute :payload, :dokku_id, :string

      validates :dokku_id, presence: true

      def self.processor
        Processors::Apps::Restart
      end
    end
  end
end
