module Apps
  class AppSourcesController < ApplicationController
    before_action :set_app, except: [:index, :new, :create, :select_git_repo]

    def index
      @app_sources = @app.sources
    end

    def new
      @app_source = @app.sources.new(type: "GithubAppSource")
    end

    def create
      @app_source = @app.sources.new(app_source_params.merge(type: "GithubAppSource"))

      if @app_source.save
        redirect_to app_sources_path(@app), notice: "App source created successfully."
      else
        render :new
      end
    end

    private

    def app_source_params
      params.require(:app_source).permit(:repo, :branch)
    end

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end

    def set_app_source
      @app_source = @app.sources.find(params[:id])
    end
  end
end
