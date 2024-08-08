module ActionDispatch
  module Routing
    class Mapper
      def modularized_resources(*resource, &block)
        options = resource.extract_options!
        scope_module = options.delete(:scope_module) || resource.first.to_s.singularize

        resources(*resource, options) do
          scope module: scope_module do
            block&.call
          end
        end
      end
    end
  end
end
