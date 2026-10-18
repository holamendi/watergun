require "test_helper"
require "timeout"

class ServiceLink::PreparationConcurrencyTest < ActiveSupport::TestCase
  # Independent committed PostgreSQL sessions are necessary to prove row order.
  self.use_transactional_tests = false

  setup do
    project = projects(:default)
    @app = project.apps.create!(server: project.server, name: "link-lock-order", status: :active)
    @service = services(:postgres)
    @variable = @app.env_variables.create!(name: "INTERNAL_#{@service.dokku_id.underscore.upcase}_URL", value: "existing")
  end

  teardown do
    runs = ServerActionRun.where(target: @app.service_links)
    ServerActionLog.where(server_action_run_id: runs.select(:id)).delete_all
    runs.delete_all
    @app.destroy!
  end

  test "service link preparation takes app before an existing environment row" do
    entered = Queue.new
    worker = nil
    @app.with_lock do
      connection = App.connection
      owner = connection.select_value("SELECT pg_backend_pid()")
      connection.execute("SET LOCAL lock_timeout = '500ms'")
      worker = Thread.new do
        App.connection_pool.with_connection do |other|
          entered << other.select_value("SELECT pg_backend_pid()")
          ServiceLink::CreateServiceLink.new(app: App.find(@app.id), service: Service.find(@service.id)).save!
        end
      end
      pid = Timeout.timeout(10) { entered.pop }
      refute_equal owner, pid
      Timeout.timeout(10) do
        loop do
          connection.execute("SELECT pg_stat_clear_snapshot()")
          break if connection.select_value("SELECT #{owner.to_i} = ANY(pg_blocking_pids(#{pid.to_i}))")
          worker.value unless worker.alive?
          Thread.pass
        end
      end
      # The link writer must not own this row while it waits for our app lock.
      @variable.update!(value: "newer-desired")
    end
    assert worker.join(10), "service link writer did not finish"
    assert worker.value
    assert @variable.reload.internal?
    assert_equal "temp", @variable.value
    assert_equal 1, @app.service_links.kept.where(env_variable: @variable).count
  ensure
    if worker&.alive?
      worker.kill
      worker.join(10)
    end
  end
end
