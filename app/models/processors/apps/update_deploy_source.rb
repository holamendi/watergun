module Processors
  module Apps
    class UpdateDeploySource < Base
      delegate :dokku_id, :github_repository, :github_branch, to: :action

      def process
        authenticate_dokku_git_account
        sync_dokku_git_repository
      end

      private

      def authenticate_dokku_git_account
        ssh.execute("dokku git:auth github.com u #{github_access_token}")
      end

      def sync_dokku_git_repository
        ssh.execute("dokku git:sync #{dokku_id} #{github_repository_url} #{github_branch}")
      end

      def github_repository_url
        "https://github.com/#{github_repository}.git"
      end

      def github_access_token
        org.github_access_token.token
      end
    end
  end
end
