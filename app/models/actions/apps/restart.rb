module Actions
  module Apps
    class Restart < Action
      include DokkuAppAction

      store_attribute :payload, :dokku_id, :string

      validates :dokku_id, presence: true

      def process_action
        restart_dokku_app
      end

      private

      def destroy_dokku_app
        ssh.execute("dokku ps:restart --force #{dokku_id}")
      end
    end
  end
end
