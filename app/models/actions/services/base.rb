module Actions
  module Services
    class Base < Actions::Base
      delegate :org, :server, :service_type, to: :eventable

      alias_method :service, :eventable
    end
  end
end
