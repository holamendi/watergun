module StoragePhaseTestHelper
  class Session
    attr_reader :bindings, :commands, :entries
    attr_accessor :fail_run_once, :ignore_run_change

    def initialize(binding, attached: false)
      @binding = binding
      @bindings = {"deploy" => attached ? [binding.dup] : [], "run" => attached ? [binding.dup] : []}
      @entries = attached ? [{"name" => binding.fetch("entry_name"), "host_path" => binding.fetch("host_path"), "scheduler" => "docker-local"}] : []
      @commands = []
    end

    def execute!(command)
      tokens = Shellwords.split(command.respond_to?(:cmd) ? command.cmd : command)
      @commands << tokens
      tokens = tokens.drop(2) if tokens.first(2) == %w[sudo -n]
      case tokens[1]
      when "plugin:trigger"
        raise "wrong trigger" unless tokens[2] == "storage-app-mounts" && tokens.size == 5
        Struct.new(:parsed_output).new(bindings.fetch(tokens[4]).map(&:dup))
      when "storage:list-entries"
        Struct.new(:parsed_output).new(entries.map(&:dup))
      when "storage:create"
        path = tokens[3].start_with?("--") ? "/var/lib/dokku/data/storage/#{tokens[2]}" : tokens[3]
        entries << {"name" => tokens[2], "host_path" => path, "scheduler" => "docker-local"}
      when "storage:mount", "storage:unmount"
        if tokens[1] == "storage:mount"
          raise "phases must converge in one write" unless tokens.last(4) == %w[--phase deploy --phase run]
        end
        %w[deploy run].each { |phase| change(phase, tokens[1] == "storage:mount", tokens[3], tokens[5]) }
      when "ps:restart", "-d"
        nil
      else
        raise "unexpected command: #{tokens.inspect}"
      end
    end

    private

    def change(phase, attach, entry_name, container_path)
      # Inject inconsistent remote state to exercise retry/phase verification;
      # production still issues only one atomic native attachment command.
      if phase == "run" && fail_run_once
        self.fail_run_once = false
        raise "run phase write failed"
      end
      return if phase == "run" && ignore_run_change
      bindings[phase].reject! { |binding| binding["entry_name"] == entry_name && binding["container_path"] == container_path }
      if attach
        entry = entries.find { |item| item["name"] == entry_name } || raise("unknown entry")
        bindings[phase] << @binding.merge("entry_name" => entry_name, "host_path" => entry.fetch("host_path"), "container_path" => container_path)
      end
    end
  end

  def native_storage_json(mount)
    name = File.basename(mount.host_path)
    [{entry: {name: name, host_path: mount.host_path, scheduler: "docker-local"}, attachment: {entry_name: name, container_path: mount.container_path, phases: %w[deploy run], process_type: "_default_"}}].to_json
  end

  def storage_phase_session(mount, attached: false)
    Session.new({"entry_name" => File.basename(mount.host_path), "host_path" => mount.host_path, "container_path" => mount.container_path, "process_type" => "_default_", "scheduler" => "docker-local"}, attached: attached)
  end
end
