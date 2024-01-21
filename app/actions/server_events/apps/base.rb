module ServerEvents
  module Apps
    class Base < ServerEvents::Base
      delegate :org, :server, to: :eventable

      alias_method :app, :eventable
    end
  end
end
