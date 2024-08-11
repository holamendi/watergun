class Projects::Apps::DeploymentsController < Projects::Apps::BaseController
  def create
    Deployment::Creator.new(app: current_app, commit_sha: params[:sha]).create!
    render turbo_stream: notify("#{current_app.name}: deployment scheduled")
  rescue ActiveRecord::RecordInvalid
    render turbo_stream: notify("Invalid deployment parameters")
  end

  def logs
    @deployment = current_app.deployments.kept.finished.find(params[:id])
    render plain: @deployment.server_action.log.to_s
  end

  private

  def github_repo
    current_app.github_repo
  end
end
