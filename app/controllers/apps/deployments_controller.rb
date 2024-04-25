module Apps
  class DeploymentsController < BaseController
    def create
      deployment = @app.deployments.new(source: "web")

      commit = if params[:sha].present?
        github_repo.remote_commit(params[:sha])
      else
        github_repo.remote_branch.commit
      end

      if commit.present?
        deployment.sha = commit.sha
        deployment.save!
        ServerActions::DeployApp.perform_later!(deployment)
        flash[:notice] = "Deployment scheduled"
        redirect_to @app
      else
        flash.now[:alert] = deployment.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    private

    def github_repo
      @app.github_repo
    end
  end
end
