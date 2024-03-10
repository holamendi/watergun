module Processors
  module Services
    class Base < Processors::Base
      alias_method :service, :actionable
    end
  end
end
