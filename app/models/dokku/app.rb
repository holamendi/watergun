module Dokku
  class App
    class << self
      def command_prefix(command)
        "dokku apps:#{command}"
      end

      def create(app)
        command_prefix("create #{app}")
      end

      def destroy(app, force: true)
        command = command_prefix("destroy #{app}")
        command += " --force" if force
        command
      end
    end
  end
end
