class DatabasesController < ApplicationController
  before_action :set_database, only: [:show, :edit, :update, :destroy, :metrics, :logs]

  def index
    # @databases = Current.server.databases
  end

  def new
    @database = Current.server.databases.new
  end

  def create
    @database = Current.server.databases.new(database_params)
    if @database.save
      redirect_to database_path(@database), notice: "database created successfully."
    else
      render :new
    end
  end

  def show
  end

  def edit
  end

  def update
    if @database.update(database_params)
      redirect_to edit_database_path(@database), notice: "database updated successfully."
    else
      render :edit
    end
  end

  def destroy
    @database.destroy
    redirect_to databases_path, notice: "database deleted successfully."
  end

  def metrics
  end

  def logs
  end

  private

  def database_params
    params.require(:database).permit(:name)
  end

  def set_database
    @database = Current.server.databases.find(params[:id])
  end
end
