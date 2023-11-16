module ServerEvents
  module Apps
    class Create < ApplicationService
      attribute :app

      validates :app, presence: true

      def call
      end
    end
  end
end
