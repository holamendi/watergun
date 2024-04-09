module Actions
  module Apps
    class Destroy < Action
      store_attribute :payload, :dokku_app_id, :string

      validates :dokku_app_id, presence: true

      def process_action
        destroy_dokku_app
      end

      private

      def destroy_dokku_app
        ssh.execute(Dokku::App.destroy(dokku_app_id))
      end
    end
  end
end
ß
