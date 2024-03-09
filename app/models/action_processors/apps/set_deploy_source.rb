module ActionProcessors
  module Apps
    class SetDeploySource < Base
      def process
        set_github_source if action.github_source?
      end

      private

      def set_github_source
        execute("dokku git:auth github.com u #{github_access_token}")
        execute("dokku git:sync #{action.dokku_id} #{github_repository} #{action.github_branch}")
      end

      def github_repository
        "https://github.com/#{action.github_repository}.git"
      end

      def github_access_token
        org.github_access_token.token
      end
    end
  end
end
