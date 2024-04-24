module Dokku
  module Git
    class Sync < Base
      attr_reader :app, :repo, :branch, :build_if_changes

      def initialize(ssh_session, app:, repo:, branch:, build_if_changes: false)
        @ssh_session = ssh_session
        @app = app
        @repo = repo
        @branch = branch
        @build_if_changes = build_if_changes
      end

      def command
        cmd = "dokku git:sync #{app} #{repo_url} #{branch}"
        cmd += " --build-if-changes" if build_if_changes
        cmd
      end

      private

      def repo_url
        "https://github.com/#{repo}.git"
      end
    end
  end
end
