module ActionProcessors
  module Services
    class Base < Base
      alias_method :service, :actionable
    end
  end
end
