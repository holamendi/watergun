module SshCommandable
  extend ActiveSupport::Concern

  included do
    include Memery

    attr_reader :ssh_session, :result

    delegate :success?,
      :failure?,
      :duration,
      :started_at,
      :finished_at,
      :output,
      :text_output, to: :result
  end

  class_methods do
    def call(ssh_session, **)
      new(ssh_session, **).call
    end

    def call!(ssh_session, **)
      new(ssh_session, **).call!
    end
  end

  def call
    @result = ssh_session.execute(command)
    self
  end

  def call!
    @result = ssh_session.execute!(command)
    self
  end

  def command
    raise "implement in subclass"
  end
end
