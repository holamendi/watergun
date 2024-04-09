module Dokku
  class Git
    class << self
      def command_prefix(command)
        "dokku git:#{command}"
      end

      def auth(url, password)
        command_prefix("auth #{url} u #{password}")
      end
    end
  end
end
