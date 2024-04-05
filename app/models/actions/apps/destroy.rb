module Actions
  module Apps
    class Destroy < Action
      store_attribute :payload, :dokku_id, :string

      validates :dokku_id, presence: true

      def self.processor
        Processors::Apps::Destroy
      end
    end
  end
end
