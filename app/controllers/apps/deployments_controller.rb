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
        deploy_action = ServerActions::DeployApp.perform_later!(deployment)
        ServerActions::EnableAppSsl.perform_later!(@app, depends_on: deploy_action)
        flash[:notice] = "Deployment scheduled"
        redirect_to @app
      else
        flash.now[:alert] = deployment.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def logs
      @deployment = @app.deployments.kept.finished.find(params[:id])
      render plain: @deployment.server_action.log.text_output
    end

    private

    def github_repo
      @app.github_repo
    end
  end
end
