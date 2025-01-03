class Projects::Apps::EnvVariablesController < Projects::Apps::BaseController
  before_action :set_env_variable, only: %i[show edit update destroy]

  def new
    @env_variable = @app.env_variables.new
  end

  def index
    @env_variables = @app.env_variables.kept
      .editable
      .includes(service_link: :service)
      .order(:name)
  end

  def create
    @env_variable = @app.env_variables.new(env_variable_params)

    if @env_variable.save
      ServerActions::UpdateEnv.run_later!(@app, set: @env_variable.to_h)

      render turbo_stream: [
        turbo_stream.remove_all("#new_env_variable form"),
        turbo_stream.prepend(
          "env_variables",
          partial: "projects/apps/env_variables/env_variable",
          locals: {env_variable: @env_variable}
        ),
        stream_toast("Environment variable created")
      ], status: :created
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @env_variable.update(env_variable_params)
      ServerActions::UpdateEnv.run_later!(@app, set: @env_variable.to_h) if @env_variable.saved_change_to_value?
      render turbo_stream: [
        turbo_stream_env_variable,
        stream_toast("Environment variable updated successfully.")
      ]
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @env_variable.discard!
    ServerActions::UpdateEnv.run_later!(@app, unset: [@env_variable.name])
    render turbo_stream: [
      turbo_stream.remove(@env_variable),
      stream_toast("Environment variable deleted successfully.")
    ]
  end

  private

  def set_env_variable
    @env_variable = @app.env_variables.kept.find(params[:id])
  end

  def env_variable_params
    params.require(:env_variable).permit(:name, :value)
  end

  def turbo_stream_env_variable
    turbo_stream.replace(
      @env_variable,
      partial: "projects/apps/env_variables/env_variable",
      locals: {env_variable: @env_variable}
    )
  end
end
