module Dokku
  class Git
    class << self
      def command_prefix(command)
        "dokku git:#{command}"
      end

      def auth(url, password)
        command_prefix("auth #{url} u #{password}")
      end

      def sync(app, repo:, branch: "main")
        command_prefix("sync #{app} #{repo} #{branch}")
      end
    end
  end
end
