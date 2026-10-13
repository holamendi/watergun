module ServerActionTestHelper
  def perform_server_operation(operation, ssh)
    operation.validate!
    operation.execute!(ssh)
    operation.succeeded!
  rescue => error
    begin
      operation.failed!
    rescue
      # Tests preserve the primary error just as the runner does.
    end
    raise error
  end

  def fail_next_domain_update(model, id, status, message)
    fired = false
    callback = lambda do |record|
      if record.id == id && record.status == status && !fired
        fired = true
        raise IOError, message
      end
    end
    model.set_callback(:update, :after, callback)
    (@domain_failure_callbacks ||= []) << [model, callback]
  end

  def after_teardown
    @domain_failure_callbacks&.each { |model, callback| model.skip_callback(:update, :after, callback) }
    super
  end

  def build_server_action_run(action, server:, target:, payload: {}, **fields)
    ServerAction::Enqueue.build(action: action, server: server, target: target, payload: payload.merge(fields))
  end

  def create_server_action_run(action, **attributes)
    build_server_action_run(action, **attributes).tap(&:save!)
  end

  def perform_server_action_run(run)
    RunServerActionJob.perform_now(run.id, run.resource_key)
    run.reload
  end

  def perform_server_action(action, server, target, **payload)
    run = create_server_action_run(action, server: server, target: target, **payload)
    perform_server_action_run(run)
  end

  def enqueue_server_action(action, server, target, **payload)
    ServerAction::Enqueue.call(action: action, server: server, target: target, payload: payload)
  end

  def assert_server_action_scheduled(klass, server:, target:, payload: nil)
    run = ServerActionRun.find_by(action_key: klass::KEY, account: server.account, server: server, target: target)
    assert run
    return unless payload.present?
    payload.each { |key, value| assert_equal value, run.payload[key.to_s] }
  end
end
