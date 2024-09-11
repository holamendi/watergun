class Projects::Apps::BuildersController < Projects::Apps::BaseController
  def update
    if @app.update(app_params)
      ServerActions::UpdateBuilder.run_later!(@app)
      render turbo_stream: notify("Builder updated")
    else
      turbo_stream_errors
    end
  end

  private

  def app_params
    params.require(:app).permit(:builder)
  end

  def turbo_stream_errors
    render turbo_stream: turbo_stream.replace(
      "builder_form",
      partial: "projects/apps/builders/form",
      locals: {
        app: @app
      }
    )
  end
end
