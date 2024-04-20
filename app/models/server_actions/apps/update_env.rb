module Actions
  module Apps
    class UpdateEnv < Action
      store_attribute :payload, :dokku_app_id, :string
      store_attribute :payload, :environment_variables, :json

      validates :dokku_app_id, presence: true
      validates :environment_variables, presence: true

      def perform
        set_dokku_app_env
      end

      private

      def set_dokku_app_env
        ssh.execute(Dokku::Config.set(dokku_app_id, environment_variables))
      end
    end
  end
end
