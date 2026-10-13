class ServerAction::LogPersistence
  def initialize(run, action)
    @run, @action = run, action
  end

  def start(session)
    @session = session
    return unless @action.class.const_defined?(:LOG_INTERVAL, false)
    @thread = Thread.new do
      loop do
        sleep @action.class::LOG_INTERVAL
        ActiveRecord::Base.connection_pool.with_connection { persist }
      rescue => error
        ServerAction::Runner.report(error, @run.id, phase: "streaming logs")
      end
    end
  end

  def stop
    @thread&.kill
    @thread&.join
    @thread = nil
  end

  def persist
    return unless @session
    commands = @session.commands
    # Ssh::Command#as_json and #text_output redact commands and sensitive output.
    log = @run.log || @run.build_log
    log.update!(ssh_commands: commands)
    @action.on_logs_persisted(commands: commands) if @action.respond_to?(:on_logs_persisted)
  end
end
