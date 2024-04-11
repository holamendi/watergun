module Actions
  module Apps
    class Create < Action
      store_attribute :payload, :dokku_app_id, :string

      validates :dokku_app_id, presence: true

      def perform
        create_dokku_app
      end

      private

      def create_dokku_app
        ssh.execute(Dokku::App.create(dokku_app_id))
      end
    end
  end
end
