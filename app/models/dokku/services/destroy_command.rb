module Dokku
  module Services
    class DestroyCommand
      def initialize(plugin:, name:, force: true)
        @plugin = plugin
        @name = name
        @force = force
      end

      def command
        cmd = "dokku #{@plugin}:destroy #{@name}"
        cmd += " --force" if @force
        cmd
      end
    end
  end
end
