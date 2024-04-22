module Dokku
  module Git
    class Sync < Base
      attr_reader :app, :repo, :branch

      def initialize(ssh_session, app:, repo:, branch:)
        @ssh_session = ssh_session
        @app = app
        @repo = repo
        @branch = branch
      end

      def call
        ssh_session.execute(command)
        self
      end

      def command
        "dokku git:sync #{app} #{repo_url} #{branch}"
      end

      private

      def repo_url
        "https://github.com/#{repo}.git"
      end
    end
  end
end
