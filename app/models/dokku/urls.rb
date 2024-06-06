module Dokku
  class Urls < Base
    attr_reader :app

    def initialize(ssh_session, app:)
      @ssh_session = ssh_session
      @app = app
    end

    def command
      "dokku urls #{app}"
    end

    def parsed_output
      return unless success?

      text_output.split("\n").map(&:strip)
    end
  end
end
