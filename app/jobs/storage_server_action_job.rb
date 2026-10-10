class StorageServerActionJob < RunServerActionJob
  # Solid Queue uses the primary database (config/application.rb). Insert its
  # job in the lifecycle transaction so either both records commit or neither.
  # Do not change the after-commit behavior of unrelated server action jobs.
  self.enqueue_after_transaction_commit = false
  # Retain the parent job's per-app semaphore across both concrete job classes.
  self.concurrency_group = "RunServerActionJob"
end
