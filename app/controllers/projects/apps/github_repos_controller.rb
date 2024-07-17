module Projects
  module Apps
    class GithubReposController < BaseController
      def new
        @github_repo = current_app.build_github_repo
      end

      def create
        @github_repo = current_app.build_github_repo(github_repo_params)

        if params[:github_access_token].present?
          @github_access_token = current_account.build_github_access_token(token: params[:github_access_token])

          unless @github_access_token.save
            flash.now[:alert] = @github_access_token.errors.full_messages.to_sentence
            return render :new, status: :unprocessable_entity
          end
        end

        if @github_repo.save
          turbo_stream_toast("App source updated successfully.")
        else
          turbo_stream_errors
        end
      end

      def edit
        @github_repo = current_app.github_repo
      end

      def update
        @github_repo = current_app.github_repo

        if @github_repo.update(github_repo_params)
          turbo_stream_toast("App source updated successfully.")
        else
          turbo_stream_errors
        end
      end

      private

      def github_repo_params
        params.require(:github_repo).permit(:repo, :branch)
      end

      def turbo_stream_errors
        render turbo_stream: turbo_stream.replace(
          "github_repo_form",
          partial: "projects/apps/github_repos/form",
          locals: {
            github_repo: @github_repo
          }
        )
      end
    end
  end
end
