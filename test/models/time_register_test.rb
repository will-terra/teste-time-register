require "test_helper"

class TimeRegisterTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "John Doe", email: "john.test.register@example.com")
  end

  test "should be valid with valid attributes" do
    time_register = TimeRegister.new(user: @user, clock_in: Time.current)
    assert time_register.valid?
  end

  test "should require clock_in" do
    time_register = TimeRegister.new(user: @user)
    assert_not time_register.valid?
    assert_includes time_register.errors[:clock_in], "can't be blank"
  end

  test "should require user" do
    time_register = TimeRegister.new(clock_in: Time.current)
    assert_not time_register.valid?
    assert_includes time_register.errors[:user], "must exist"
  end

  test "should not allow multiple open registers for same user" do
    # Create first open register
    TimeRegister.create!(user: @user, clock_in: 1.hour.ago)
    
    # Try to create second open register
    time_register = TimeRegister.new(user: @user, clock_in: Time.current)
    assert_not time_register.valid?
    assert_includes time_register.errors[:base], "User already has an open time register"
  end

  test "should allow multiple open registers for different users" do
    user2 = User.create!(name: "Jane Doe", email: "jane.test.register@example.com")
    
    TimeRegister.create!(user: @user, clock_in: 1.hour.ago)
    time_register = TimeRegister.new(user: user2, clock_in: Time.current)
    
    assert time_register.valid?
  end

  test "should allow new register after closing previous one" do
    # Create and close first register
    first_register = TimeRegister.create!(user: @user, clock_in: 2.hours.ago)
    first_register.update!(clock_out: 1.hour.ago)
    
    # Create new open register
    second_register = TimeRegister.new(user: @user, clock_in: Time.current)
    assert second_register.valid?
  end

  test "clock_out must be after clock_in" do
    clock_in_time = Time.current
    time_register = TimeRegister.new(
      user: @user,
      clock_in: clock_in_time,
      clock_out: clock_in_time - 1.hour
    )
    
    assert_not time_register.valid?
    assert_includes time_register.errors[:clock_out], "must be after clock in time"
  end

  test "should be valid when clock_out is after clock_in" do
    clock_in_time = Time.current
    time_register = TimeRegister.new(
      user: @user,
      clock_in: clock_in_time,
      clock_out: clock_in_time + 1.hour
    )
    
    assert time_register.valid?
  end

  test "should be valid when clock_out is nil" do
    time_register = TimeRegister.new(user: @user, clock_in: Time.current, clock_out: nil)
    assert time_register.valid?
  end

end
