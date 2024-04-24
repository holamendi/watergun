module Dokku
  class Base
    attr_reader :ssh_session, :result

    def self.call(ssh_session, **)
      new(ssh_session, **).call
    end

    def call
      @result = ssh_session.execute(command)
      self
    end

    def command
      raise "implement in subclass"
    end

    def success?
      result&.success?
    end
  end
end
