module Api
  module V1
    class DeploymentsController < ApplicationController
      before_action :set_app, :set_github_repo, only: [:create]

      def index
        deployments = current_account.deployments.kept
        deployments = deployments.where(app_id: params[:app_id]) if params[:app_id].present?
        render json: DeploymentResource.new(deployments)
      end

      def show
        deployment = if params[:app_id].present?
          set_app
          @app.deployments.kept.find(params[:id])
        else
          current_account.deployments.kept.find(params[:id])
        end

        render json: DeploymentResource.new(deployment)
      end

      def create
        commit = if params[:sha].present?
          @github_repo.remote_commit(params[:sha])
        else
          @github_repo.remote_branch.commit
        end

        if commit.present?
          deployment = @app.deployments.create!(
            sha: commit.sha,
            author_login: commit.author.login,
            author_url: commit.author.html_url,
            author_avatar_url: commit.author.avatar_url,
            author_date: commit.commit.author.date,
            commit_message: commit.commit.message,
            commit_html_url: commit.html_url
          )
          ServerActions::DeployApp.run_later!(deployment)
          render json: DeploymentResource.new(deployment), status: :created
        else
          render json: {errors: "invalid commit"}, status: :unprocessable_entity
        end
      end

      private

      def set_app
        @app = current_account.apps.kept.find(params[:app_id])
      end

      def set_github_repo
        @github_repo = @app.github_repo

        unless @github_repo.present?
          render json: {errors: ["Github repo not found"]}, status: :not_found
        end
      end
    end
  end
end
