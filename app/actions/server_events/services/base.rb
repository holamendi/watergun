module ServerEvents
  module Apps
    class Base < ServerEvents::Base
      delegate :org, :server, :service_type, to: :eventable

      alias_method :service, :eventable
    end
  end
end
