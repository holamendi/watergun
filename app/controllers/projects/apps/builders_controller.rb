class Projects::Apps::BuildersController < Projects::Apps::BaseController
  def update
    if @app.update_builder_and_sync(app_params.fetch(:builder, @app.builder))
      render turbo_stream: stream_toast("Builder updated to #{@app.builder}")
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
