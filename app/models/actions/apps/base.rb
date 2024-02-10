module Actions
  module Apps
    class Base < Actions::Base
      delegate :org, :server, to: :eventable

      alias_method :app, :eventable
    end
  end
end
