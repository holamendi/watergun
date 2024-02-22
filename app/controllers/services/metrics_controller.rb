module Services
  class MetricsController < BaseController
    def show
      @running_containers = @service.containers.running
    end
  end
end
