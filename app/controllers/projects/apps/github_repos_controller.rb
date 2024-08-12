class Projects::Apps::GithubReposController < Projects::Apps::BaseController
  before_action :set_github_repo, only: %i[edit update]

  def new
    @github_repo = current_app.build_github_repo
  end

  def create
  end

  def edit
  end

  def update
    if @github_repo.update(update_github_repo_params)
      render turbo_stream: notify("Settings updated")
    else
      render turbo_stream: render_form, status: :unprocessable_entity
    end
  end

  private

  def set_github_repo
    @github_repo = current_app.github_repo
  end

  def update_github_repo_params
    params.require(:github_repo).permit(:webhook_deploy)
  end

  def render_form
    turbo_stream.replace(
      "github_repo_form",
      partial: "projects/apps/github_repos/form",
      locals: {github_repo: @github_repo}
    )
  end
end
