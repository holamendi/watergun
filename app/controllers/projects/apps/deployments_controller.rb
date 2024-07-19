module Projects
  module Apps
    class DeploymentsController < BaseController
      def create
        commit = if params[:sha].present?
          github_repo.remote_commit(params[:sha])
        else
          github_repo.remote_branch.commit
        end

        if commit.present?
          deployment = current_app.deployments.create!(
            sha: commit.sha,
            author_login: commit.author.login,
            author_url: commit.author.html_url,
            author_avatar_url: commit.author.avatar_url,
            author_date: commit.commit.author.date,
            commit_message: commit.commit.message,
            commit_html_url: commit.html_url
          )
          ServerAction::DeployApp.run_later!(deployment)
          turbo_stream_toast("#{current_app.name}: deployment scheduled")
        else
          flash.now[:alert] = deployment.errors.full_messages.to_sentence
          render :new, status: :unprocessable_entity
        end
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
  end
end
