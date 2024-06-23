module Projects
  module Apps
    class GithubReposController < BaseController
      def new
        @github_repo = current_app.build_github_repo
      end

      def create
        @github_repo = current_app.build_github_repo(github_repo_params)

        if params[:github_access_token].present?
          @github_access_token = current_org.build_github_access_token(token: params[:github_access_token])

          unless @github_access_token.save
            flash.now[:alert] = @github_access_token.errors.full_messages.to_sentence
            return render :new, status: :unprocessable_entity
          end
        end

        if @github_repo.save
          redirect_to current_project, notice: "App source updated successfully."
        else
          render turbo_stream: turbo_stream.replace(
            @github_repo,
            partial: "projects/apps/github_repos/form",
            locals: {
              github_repo: @github_repo
            }
          )
        end
      end

      def edit
        @github_repo = current_app.github_repo
      end

      def update
        @github_repo = current_app.github_repo

        if @github_repo.update(github_repo_params)
          redirect_to current_project, notice: "App source updated successfully."
        else
          render turbo_stream: turbo_stream.replace(
            @github_repo,
            partial: "projects/apps/github_repos/form",
            locals: {
              github_repo: @github_repo
            }
          )
        end
      end

      private

      def github_repo_params
        params.require(:github_repo).permit(:repo, :branch)
      end
    end
  end
end
