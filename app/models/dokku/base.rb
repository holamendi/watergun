module Dokku
  class Base
    attr_reader :ssh_session, :result

    delegate :success?, :failure?, :duration, :started_at, :completed_at, :output, to: :result

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
  end
end
