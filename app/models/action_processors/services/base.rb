module ActionProcessors
  module Services
    class Base < ActionProcessors::Base
      alias_method :service, :actionable
    end
  end
end
