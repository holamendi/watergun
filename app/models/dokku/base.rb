module Dokku
  class Base
    include Memery

    attr_reader :ssh_session, :result

    delegate :success?,
      :failure?,
      :duration,
      :started_at,
      :finished_at,
      :output,
      :text_output, to: :result

    def self.call(ssh_session, **)
      new(ssh_session, **).call
    end

    def self.call!(ssh_session, **)
      new(ssh_session, **).call!
    end

    def call
      @result = ssh_session.execute(command)
      self
    end

    def call!
      raise Dokku::CommandExecutionError.new("dokku command failed: #{command}", result) if call.failure?
      self
    end

    def command
      raise "implement in subclass"
    end
  end
end
