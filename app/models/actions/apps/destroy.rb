module Actions
  module Apps
    class Destroy < Action
      include DokkuAppAction

      def process_action
        destroy_dokku_app
      end
    end
  end
end
