module Dokku
  class Base
    attr_reader :ssh_session, :command

    def self.call(*, **)
      new(*, **).call
    end

    def success?
      command&.success?
    end
  end
end
