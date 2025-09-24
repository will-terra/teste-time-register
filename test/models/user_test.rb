require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = User.new(name: "John Doe", email: "john.test@example.com")
    assert user.valid?
  end

  test "should require name" do
    user = User.new(email: "john.test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "should require email" do
    user = User.new(name: "John Doe")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should require unique email" do
    User.create!(name: "John Doe", email: "john.unique@example.com")
    user = User.new(name: "Jane Doe", email: "john.unique@example.com")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "should validate email format" do
    user = User.new(name: "John Doe", email: "invalid-email")
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "should accept valid email formats" do
    valid_emails = ["test.user@example.com", "user.name@domain.co.uk", "user+tag@example.org"]
    
    valid_emails.each do |email|
      user = User.new(name: "Test User", email: email)
      assert user.valid?, "#{email} should be valid"
    end
  end

  test "has_open_time_register? should return true when user has open register" do
    user = User.create!(name: "John Doe", email: "john.open@example.com")
    user.time_registers.create!(clock_in: Time.current)
    
    assert user.has_open_time_register?
  end

  test "has_open_time_register? should return false when user has no open register" do
    user = User.create!(name: "John Doe", email: "john.closed@example.com")
    
    assert_not user.has_open_time_register?
  end
end
