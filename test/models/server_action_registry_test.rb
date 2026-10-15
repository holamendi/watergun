require "test_helper"

class ServerActionRegistryTest < ActiveSupport::TestCase
  test "duplicate keys and incomplete contracts are rejected" do
    assert_raises(ArgumentError) { ServerAction::Registry.register([ServerActions::RestartApp, ServerActions::RestartApp]) }
    invalid = Class.new
    invalid.const_set(:KEY, "invalid")
    assert_raises(ArgumentError) { ServerAction::Registry.register([invalid]) }
    assert_raises(ArgumentError) { ServerAction::Registry.register([Class.new]) }
  end
  test "actions without a public class default_payload method are rejected" do
    invalid = Class.new do
      def validate!
      end

      def execute!(ssh)
      end

      def succeeded!
      end

      def failed!
      end
    end
    invalid.const_set(:KEY, "invalid")

    assert_raises(ArgumentError) { ServerAction::Registry.register([invalid]) }

    invalid.define_singleton_method(:default_payload) { |target| {} }
    assert_equal({"invalid" => invalid}, ServerAction::Registry.register([invalid]))

    invalid.private_class_method :default_payload
    assert_raises(ArgumentError) { ServerAction::Registry.register([invalid]) }
  end

  test "registry covers exactly the concrete action files" do
    concrete_actions = Rails.root.join("app/models/server_actions").glob("**/*.rb").map do |path|
      path.relative_path_from(Rails.root.join("app/models")).to_s.delete_suffix(".rb").camelize.constantize
    end
    assert_equal concrete_actions.sort_by(&:name), ServerAction::Registry::ACTIONS.values.sort_by(&:name)
  end

  test "infrastructure is a module and concrete actions satisfy the plain class contract" do
    assert_instance_of Module, ServerAction
    ServerAction::Registry::ACTIONS.each do |key, klass|
      assert_same klass, ServerAction::Registry.fetch(key)
      refute klass < ActiveRecord::Base
      assert_respond_to klass, :default_payload
      %i[validate! execute! succeeded! failed!].each { |method| assert klass.method_defined?(method) }
    end
  end
end
