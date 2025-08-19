class Projects::Apps::DeploymentsController < Projects::Apps::BaseController
  def index
    @deployments = @app.deployments.kept.order(created_at: :desc).limit(5)
  end

  def create
    Deployment::CreateDeployment.new(app: @app, commit_sha: params[:sha]).save!
    render turbo_stream: stream_toast("#{@app.name}: deployment scheduled")
  rescue ActiveModel::ValidationError
    render turbo_stream: stream_toast("Invalid deployment parameters"), status: :unprocessable_content
  end

  def logs
    @deployment = @app.deployments.kept.finished.find(params[:id])
    render plain: @deployment.server_action.log.to_s
  end
end
