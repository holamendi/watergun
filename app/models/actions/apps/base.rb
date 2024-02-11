module Actions
  module Apps
    class Base < Actions::Base
      delegate :org, :server, to: :actionable
    end
  end
end
