module Dokku
  class Ps
    class << self
      def command_prefix(command)
        "dokku ps:#{command}"
      end

      def restart(app)
        command_prefix("restart #{app}")
      end

      def rebuild(app)
        command_prefix("rebuild #{app}")
      end
    end
  end
end
