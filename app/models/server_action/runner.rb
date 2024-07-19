module ServerAction::Runner
  extend ActiveSupport::Concern

  included do
    attr_accessor :ssh_session
    alias_method :ssh, :ssh_session
  end

  class_methods do
    def run_later!(actionable, depends_on: nil, **)
      action = create!(actionable:, preceding_action: depends_on, **)
      RunServerActionJob.set(wait: 1.second).perform_later(action)

      action
    end
  end

  def run_action
    raise "server action must implement #run" unless respond_to?(:run, true)

    running!
    session = server.ssh_session do |ssh_session|
      with(ssh_session:) do
        run
      rescue Ssh::CommandExecutionError
      end
    end

    create_log!(ssh_commands: session.commands)
    self.status = session.status
    self
  rescue => e
    self.status = :error
    Honeybadger.notify(e, context: {server_action_id: id})
    raise if Rails.env.development?
    self
  ensure
    self.finished_at = Time.current
    save!
  end
end
