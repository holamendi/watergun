module StorageOperation
  def run_later(wait: 0.seconds)
    job = StorageServerActionJob.new(self)
    result = job.enqueue(wait: wait)
    unless result && job.successfully_enqueued?
      raise(job.enqueue_error || ActiveJob::EnqueueError.new("Storage operation was not enqueued"))
    end
    job
  end

  private

  def storage_phase_bindings
    %w[deploy run].to_h do |phase|
      [phase, execute!(Dokku::Storage::ListCommand.new(app: dokku_app_id, phase: phase)).parsed_output]
    end
  end

  def validate_storage_scope!(phases)
    targets = phases.values.flatten.select { |mount| mount["container_path"] == container_path }
    if targets.any? { |mount| mount["process_type"].present? && mount["process_type"] != "_default_" }
      raise "Container path has a process-specific storage attachment; operator intervention required"
    end
  end

  def binding_present?(mounts)
    mounts.any? { |mount| mount["host_path"] == host_path && mount["container_path"] == container_path && (mount["process_type"].blank? || mount["process_type"] == "_default_") }
  end
end
