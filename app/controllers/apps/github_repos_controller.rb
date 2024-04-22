module Apps
  class GithubReposController < BaseController
    def new
      @github_repo = @app.build_github_repo
    end

    def create
      @github_repo = @app.build_github_repo(github_repo_params)

      if @github_repo.save
        redirect_to @app, notice: "App source created successfully."
      else
        flash.now[:alert] = @github_repo.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    private

    def github_repo_params
      params.require(:github_repo).permit(:repo, :branch)
    end
  end
end
