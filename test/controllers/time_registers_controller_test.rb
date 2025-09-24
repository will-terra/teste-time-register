require "test_helper"

class TimeRegistersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @time_register = time_registers(:one)
  end

  test "should get index" do
    get time_registers_url, as: :json
    assert_response :success
  end

  test "should create time_register" do
    assert_difference("TimeRegister.count") do
      post time_registers_url, params: { time_register: { clock_in: @time_register.clock_in, clock_out: @time_register.clock_out, user_id: @time_register.user_id } }, as: :json
    end

    assert_response :created
  end

  test "should show time_register" do
    get time_register_url(@time_register), as: :json
    assert_response :success
  end

  test "should update time_register" do
    patch time_register_url(@time_register), params: { time_register: { clock_in: @time_register.clock_in, clock_out: @time_register.clock_out, user_id: @time_register.user_id } }, as: :json
    assert_response :success
  end

  test "should destroy time_register" do
    assert_difference("TimeRegister.count", -1) do
      delete time_register_url(@time_register), as: :json
    end

    assert_response :no_content
  end
end
