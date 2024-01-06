module ServerEvents
  module Apps
    class Deploy < Base
      def commands
        [
          "dokku git:auth github.com u #{app.org.git_credential.personal_access_token}",
          "dokku git:sync --build #{app.dokku_name} http://github.com/#{app.git_repo}.git #{app.git_branch}"
        ]
      end
    end
  end
end
