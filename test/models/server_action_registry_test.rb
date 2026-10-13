require "test_helper"

class ServerActionRegistryTest < ActiveSupport::TestCase
  test "duplicate keys and incomplete contracts are rejected" do
    assert_raises(ArgumentError) { ServerAction::Registry.register([ServerActions::RestartApp, ServerActions::RestartApp]) }
    invalid = Class.new
    invalid.const_set(:KEY, "invalid")
    assert_raises(ArgumentError) { ServerAction::Registry.register([invalid]) }
    assert_raises(ArgumentError) { ServerAction::Registry.register([Class.new]) }
  end
  test "infrastructure is a module and concrete actions are not records" do
    assert_instance_of Module, ServerAction
    assert_equal 18, ServerAction::Registry::ACTIONS.size
    ServerAction::Registry::ACTIONS.each do |key, klass|
      assert_equal key, ServerAction::Registry.key_for(klass)
      refute klass < ActiveRecord::Base
      %i[validate! execute! succeeded! failed!].each { |method| assert klass.method_defined?(method) }
    end
  end
end
