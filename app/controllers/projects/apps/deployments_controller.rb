class Projects::Apps::DeploymentsController < Projects::Apps::BaseController
  def index
    @deployments = @app.deployments.kept.order(created_at: :desc).limit(10)
  end

  def create
    Deployment::Creator.new(app: @app, commit_sha: params[:sha]).create!
    render turbo_stream: append_toast("#{@app.name}: deployment scheduled")
  rescue ActiveRecord::RecordInvalid
    render turbo_stream: append_toast("Invalid deployment parameters")
  end

  def logs
    @deployment = @app.deployments.kept.finished.find(params[:id])
    render plain: @deployment.server_action.log.to_s
  end
end
