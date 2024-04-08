require "test_helper"

class OrgTest < ActiveSupport::TestCase
  test "should not save org without name" do
    org = Org.new
    puts Org.count
    assert_not org.save
  end

  test "should save org with name" do
    Org.destroy_all
    puts Org.count
  end

  test "should save org witssh name" do
    puts Org.count
  end
end
