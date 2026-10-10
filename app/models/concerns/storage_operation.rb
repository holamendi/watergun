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

  def binding_present?(mounts)
    mounts.any? { |mount| mount["host_path"] == host_path && mount["container_path"] == container_path }
  end
end
