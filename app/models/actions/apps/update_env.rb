module Actions
  module Apps
    class UpdateEnv < Action
      store_attribute :payload, :dokku_id, :string
      store_attribute :payload, :environment_variables, :json

      validates :dokku_id, presence: true
      validates :environment_variables, presence: true

      def self.processor
        Processors::Apps::UpdateEnv
      end
    end
  end
end
