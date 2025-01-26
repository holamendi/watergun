require "test_helper"

class EnvVariableTest < ActiveSupport::TestCase
  describe "validations" do
    test "name must start with letter or underscore" do
      env_variable = EnvVariable.new(name: "1var", value: "value", app: apps(:smol_roda))

      refute env_variable.valid?
      assert_includes env_variable.errors[:name], "is invalid"

      env_variable.name = "_var"

      assert env_variable.valid?

      env_variable.name = "myVAR"

      assert env_variable.valid?
    end

    test "name can only contain letters, numbers and underscores" do
      env_variable = EnvVariable.new(name: "1var", value: "value", app: apps(:smol_roda))

      refute env_variable.valid?
      assert_includes env_variable.errors[:name], "is invalid"

      env_variable.name = "my.var"

      refute env_variable.valid?
      assert_includes env_variable.errors[:name], "is invalid"

      env_variable.name = "MY_var_123"

      assert env_variable.valid?
    end
  end
end
