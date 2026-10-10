module StoragePhaseTestHelper
  class Session
    attr_reader :bindings, :commands
    attr_accessor :fail_run_once, :ignore_run_change

    def initialize(binding, attached: false)
      @binding = binding
      @bindings = {"deploy" => attached ? [binding] : [], "run" => attached ? [binding] : []}
      @commands = []
    end

    def execute!(command)
      tokens = Shellwords.split(command.respond_to?(:cmd) ? command.cmd : command)
      @commands << tokens
      tokens = tokens.drop(2) if tokens.first(2) == %w[sudo -n]
      case tokens[1]
      when "storage:list"
        Struct.new(:parsed_output).new(bindings.fetch("deploy").map(&:dup))
      when "plugin:trigger"
        raise "wrong trigger" unless tokens[2] == "storage-list" && tokens[5] == "json"
        Struct.new(:parsed_output).new(bindings.fetch(tokens[4]).map(&:dup))
      when "storage:mount", "storage:unmount"
        %w[deploy run].each { |phase| change(phase, tokens[1] == "storage:mount") }
      when "docker-options:add", "docker-options:remove"
        raise "wrong option" unless tokens[4].start_with?("-v ")
        change(tokens[3], tokens[1] == "docker-options:add")
      when "storage:ensure-directory", "ps:restart", "-d"
        nil
      else
        raise "unexpected command: #{tokens.inspect}"
      end
    end

    private

    def change(phase, attach)
      if phase == "run" && fail_run_once
        self.fail_run_once = false
        raise "run phase write failed"
      end
      return if phase == "run" && ignore_run_change
      bindings[phase] = attach ? [@binding] : []
    end
  end

  def storage_phase_session(mount, attached: false)
    Session.new({"host_path" => mount.host_path, "container_path" => mount.container_path}, attached: attached)
  end
end
