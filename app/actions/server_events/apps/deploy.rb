module ServerEvents
  module Apps
    class Deploy < Base
      def eventable_status
        "deploying"
      end

      def commands
        [
          "dokku git:auth github.com u #{org.git_credential.personal_access_token}",
          "dokku git:sync --build #{app.dokku_name} http://github.com/#{app.git_repo}.git #{app.git_branch}"
        ]
      end
    end
  end
end
