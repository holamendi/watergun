module Apps
  class DatabasesController < ApplicationController
    before_action :set_app

    def index
      @database_links = @app.database_links.kept.joins(:database).order("databases.name")
    end

    def new
      @database = current_server.databases.new
    end

    def create
      @database = current_server.databases.new(database_params)

      if @database.save
        database_link = @app.database_links.create!(database: @database)

        create_database_action = ServerActions::CreateDatabase.perform_later!(@database)
        ServerActions::LinkDatabase.perform_later!(database_link, depends_on: create_database_action)

        redirect_to app_databases_path(@app), notice: "Database created successfully."
      else
        render :new
      end
    end

    def destroy
      @database = @app.databases.kept.find(params[:id])
      database_link = @database.database_links.kept.find_by(app: @app)

      database_link.discard!
      unlink_action = ServerActions::UnlinkDatabase.perform_later!(database_link)
      @database.discard!
      ServerActions::DestroyDatabase.perform_later!(@database, depends_on: unlink_action)

      redirect_to app_databases_path(@app), notice: "Database scheduled for deletion"
    end

    private

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end

    def database_params
      params.require(:database).permit(:name, :service_type)
    end
  end
end
