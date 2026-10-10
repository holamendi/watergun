module Dokku
  module Storage
    class CreateEntry
      def initialize(name:, path: nil, chown: nil)
        @name = name
        @path = path
        @chown = chown
      end

      def cmd
        tokens = ["dokku", "storage:create", @name]
        tokens << @path if @path
        tokens += ["--chown", @chown.presence || "false"] unless @path
        Shellwords.join(tokens)
      end
    end
  end
end
