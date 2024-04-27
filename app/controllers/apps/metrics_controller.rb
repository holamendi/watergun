module Apps
  class MetricsController < BaseController
    def show
      @running_containers = @app.containers.running
    end
  end
end
