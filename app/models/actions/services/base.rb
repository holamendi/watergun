module Actions
  module Services
    class Base < Actions::Base
      delegate :org, :server, :service_type, to: :actionable

      alias_method :service, :actionable
    end
  end
end
