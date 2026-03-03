class Projects::Apps::EnvVariablesController < Projects::Apps::BaseController
  before_action :set_env_variable, only: %i[show edit update destroy]

  def new
    @env_variable = @app.env_variables.new
  end

  def index
    @env_variables = env_variables_scope
  end

  def create
    @env_variable = @app.env_variables.new(env_variable_params)

    if @env_variable.save
      ServerActions::UpdateEnv.run_later!(@app.server, @app, set: @env_variable.to_h)

      render turbo_stream: [
        stream_env_variables,
        close_modal_stream,
        stream_toast("Environment variable created")
      ], status: :created
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @env_variable.update(env_variable_params)
      ServerActions::UpdateEnv.run_later!(@app.server, @app, set: @env_variable.to_h) if @env_variable.saved_change_to_value?
      render turbo_stream: [
        stream_env_variables,
        close_modal_stream,
        stream_toast("Environment variable updated successfully.")
      ]
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @env_variable.discard!
    ServerActions::UpdateEnv.run_later!(@app.server, @app, unset: [@env_variable.name])
    render turbo_stream: [
      stream_env_variables,
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

  def env_variables_scope
    @app.env_variables.kept
      .editable
      .includes(service_link: :service)
      .order(:name)
  end

  def stream_env_variables
    turbo_stream.replace(
      "env_variables_section",
      partial: "projects/apps/env_variables/env_variables",
      locals: {
        project: @project,
        app: @app,
        env_variables: env_variables_scope
      }
    )
  end

  def close_modal_stream
    turbo_stream.action(:close_dialog, "env_var_modal")
  end
end
