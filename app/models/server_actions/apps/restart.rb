module Actions
  module Apps
    class Restart < Action
      store_attribute :payload, :dokku_app_id, :string

      validates :dokku_app_id, presence: true

      def perform
        restart_dokku_app
      end

      private

      def restart_dokku_app
        ssh.execute(Dokku::Ps.restart(dokku_app_id))
      end
    end
  end
end
