module Dokku
  module Git
    class SyncCommand
      def initialize(app:, repo:, branch: nil, sha: nil, build_if_changes: false)
        @app = app
        @repo = repo
        @branch = branch
        @sha = sha
        @build_if_changes = build_if_changes
      end

      def command
        cmd = "dokku git:sync #{@app} #{repo_url} #{@sha || @branch}"
        cmd += " --build-if-changes" if @build_if_changes
        cmd
      end

      private

      def repo_url
        "https://github.com/#{@repo}.git"
      end
    end
  end
end
