module ServerActions
  module Processor
    extend ActiveSupport::Concern

    def ssh_session(&)
      raise "server action must implement #perform" unless respond_to?(:perform)

      self.running_at = Time.current
      running!

      result = server.ssh_session(&)
      create_log!(org:, ssh_commands: result.commands)

      self.completed_at = result.completed_at
      result.success? ? success! : failure!
    rescue => e
      self.completed_at = Time.current
      failure!

      raise e if Rails.env.local?
    end
  end
end
