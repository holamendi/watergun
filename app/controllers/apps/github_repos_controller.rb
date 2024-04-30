module Apps
  class GithubReposController < BaseController
    def new
      @github_repo = @app.build_github_repo
    end

    def create
      @github_repo = @app.build_github_repo(create_github_repo_params)

      if params[:github_access_token].present?
        @github_access_token = current_org.build_github_access_token(token: params[:github_access_token])

        unless @github_access_token.save
          flash.now[:alert] = @github_access_token.errors.full_messages.to_sentence
          return render :new, status: :unprocessable_entity
        end
      end

      if @github_repo.save
        redirect_to @app, notice: "App source created successfully."
      else
        flash.now[:alert] = @github_repo.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @github_repo = @app.github_repo
    end

    def update
      @github_repo = @app.github_repo

      if @github_repo.update(update_github_repo_params)
        redirect_to @app, notice: "App source updated successfully."
      else
        flash.now[:alert] = @github_repo.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def create_github_repo_params
      params.require(:github_repo).permit(:repo, :branch)
    end

    def update_github_repo_params
      params.require(:github_repo).permit(:branch)
    end
  end
end
