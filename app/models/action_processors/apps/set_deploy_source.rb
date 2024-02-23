module ActionProcessors
  module Apps
    class SetDeploySource < Base
      def process
        sync_github_repository
      end

      private

      def sync_github_repository
        execute("dokku git:auth github.com u #{github_access_token}")
        execute("dokku git:sync #{app.dokku_id} #{github_repository} #{github_branch}")
      end

      def github_repository
        "https://github.com/#{app.deploy_source.repository}.git"
      end

      def github_branch
        app.deploy_source.branch
      end

      def github_access_token
        org.github_access_token.token
      end
    end
  end
end
