module Projects
  class DatabasesController < BaseController
    def create
      @database = current_project.databases.new(database_params)

      if @database.save
        ServerActions::CreateService.perform_later!(@database)

        database_link = @app.database_links.create!(database: @database)

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
