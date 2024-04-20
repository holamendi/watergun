module Dokku
  module Plugins
    class Letsencrypt
      class << self
        def command_prefix(command)
          "dokku letsencrypt:#{command}"
        end

        def enable(app)
          command_prefix("enable #{app}")
        end

        def active(app)
          command_prefix("active #{app}")
        end
      end
    end
  end
end
