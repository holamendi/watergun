module Apps
  class DeploymentsController < ApplicationController
    before_action :set_app

    def create
      commit = if params[:sha].present?
        github_repo.remote_commit(params[:sha])
      else
        github_repo.remote_branch.commit
      end

      if commit.present?
        deployment = @app.deployments.create!(
          sha: commit.sha,
          author_url: commit.author.html_url,
          author_avatar_url: commit.author.avatar_url,
          author_date: commit.commit.author.date,
          commit_message: commit.commit.message,
          commit_html_url: commit.html_url
        )
        ServerActions::DeployApp.perform_later!(deployment)
        flash[:notice] = "Deployment scheduled"
        redirect_to @app
      else
        flash.now[:alert] = deployment.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def logs
      @deployment = @app.deployments.kept.finished.find(params[:id])
      render plain: @deployment.server_action.log.to_s
    end

    private

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end

    def github_repo
      @app.github_repo
    end
  end
end
