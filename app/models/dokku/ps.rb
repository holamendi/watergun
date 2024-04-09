module Dokku
  class Ps
    class << self
      def command_prefix(command)
        "dokku ps:#{command}"
      end

      def restart(app)
        command_prefix("restart #{app}")
      end
    end
  end
end
