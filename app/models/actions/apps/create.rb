module Actions
  module Apps
    class Create < Action
      include DokkuAppAction

      def process_action
        create_dokku_app
      end
    end
  end
end
