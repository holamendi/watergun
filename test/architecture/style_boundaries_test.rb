require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"
require "json"

# Isolated syntax fixtures, not Rails execution or simulated deployment evidence.
class StyleBoundariesTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def setup
    @root = Dir.mktmpdir("watergun-architecture-")
    write("Archspec.rb", File.read(File.join(ROOT, "Archspec.rb")))
    write("app/models/application_record.rb", "class ApplicationRecord < ActiveRecord::Base; end\n")
    write("app/models/app.rb", "class App < ApplicationRecord\n  def deployed? = deployed_at.present?\nend\n")
    write("app/models/env_variable.rb", "class EnvVariable < ApplicationRecord\n  def reserved? = name.start_with?(\"DOKKU_\")\nend\n")
    write("app/models/deployment.rb", "class Deployment < ApplicationRecord; end\n")
    write("app/models/app/create_app.rb", <<~RUBY)
      class App::CreateApp
        def save
          ApplicationRecord.transaction { @app.save! }
          true
        end
      end
    RUBY
    write("app/models/current.rb", "class Current < ActiveSupport::CurrentAttributes\n  attribute :account, :user\nend\n")
    write("test/owned_test.rb", <<~RUBY)
      class OwnedTest < ActiveSupport::TestCase
        self.use_transactional_tests = false
        teardown { ApiToken.where(id: @token.id).delete_all }
      end
    RUBY
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_plain_services_rich_records_transactions_and_owned_cleanup_are_allowed
    result, status = archspec
    assert status.success?, result.inspect
    assert_empty result.fetch("violations")
    findings, status = style
    assert status.success?, findings.inspect
    assert_empty findings
  end

  def test_record_cannot_directly_enqueue
    write("app/models/env_variable.rb", <<~RUBY)
      class EnvVariable < ApplicationRecord
        def save_and_sync
          save!
          ServerAction::Enqueue.call(action: "apps.update_env", target: app)
        end
      end
    RUBY
    assert_architecture_rejected
  end

  def test_record_cannot_hide_workflow_dispatch_through_a_service
    write("app/models/app.rb", <<~RUBY)
      class App < ApplicationRecord
        def recreate
          App::CreateApp.new.save
        end
      end
    RUBY
    assert_architecture_rejected
  end

  def test_call_only_lifecycle_service_is_rejected
    write("app/models/app/create_app.rb", <<~RUBY)
      class App::CreateApp
        def call
          @app.save!
        end
      end
    RUBY
    assert_architecture_rejected
  end

  def test_current_cannot_declare_workflow_control
    %i[accepting_server_action executing_server_action].each do |name|
      write("app/models/current.rb", "class Current < ActiveSupport::CurrentAttributes\n  attribute :account, :#{name}\nend\n")
      findings, status = style
      refute status.success?, name.to_s
      assert_equal ["current.context_only"], findings.map { |finding| finding.fetch("rule") }
    end
  end

  def test_nontransactional_table_wide_cleanup_is_rejected
    write("test/owned_test.rb", <<~RUBY)
      class OwnedTest < ActiveSupport::TestCase
        self.use_transactional_tests = false
        teardown { ApiToken.delete_all }
      end
    RUBY
    findings, status = style
    refute status.success?
    assert_equal ["tests.no_table_wide_cleanup"], findings.map { |finding| finding.fetch("rule") }
  end

  def test_transactional_empty_database_setup_is_not_banned
    write("test/owned_test.rb", <<~RUBY)
      class OnboardingTest < ActiveSupport::TestCase
        setup { Account.destroy_all }
      end
    RUBY
    findings, status = style
    assert status.success?, findings.inspect
    assert_empty findings
  end

  private

  def write(path, content)
    target = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(target))
    File.write(target, content)
  end

  def archspec
    output, errors, status = Open3.capture3("bundle", "exec", "archspec", "check", "--config", File.join(@root, "Archspec.rb"), "--format", "json", chdir: @root)
    assert errors.empty?, errors
    [JSON.parse(output), status]
  end

  def style
    output, errors, status = Open3.capture3("bundle", "exec", "ruby", File.join(ROOT, "script/check-style-boundaries"), @root)
    assert errors.empty?, errors
    [JSON.parse(output), status]
  end

  def assert_architecture_rejected
    result, status = archspec
    refute status.success?, result.inspect
    refute_empty result.fetch("violations")
  end
end
