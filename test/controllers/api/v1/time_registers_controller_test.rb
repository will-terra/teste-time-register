require "test_helper"

class Api::V1::TimeRegistersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @time_register = time_registers(:one)
  end

  test "should get index" do
    get api_v1_time_registers_url, as: :json
    assert_response :success
  end

  test "should create time_register" do
    user = users(:one)
    assert_difference("TimeRegister.count") do
      post api_v1_time_registers_url, params: { 
        time_register: { 
          clock_in: Time.current, 
          user_id: user.id 
        } 
      }, as: :json
    end

    assert_response :created
  end

  test "should show time_register" do
    get api_v1_time_register_url(@time_register), as: :json
    assert_response :success
  end

  test "should update time_register" do
    patch api_v1_time_register_url(@time_register), params: { 
      time_register: { 
        clock_out: Time.current + 8.hours 
      } 
    }, as: :json
    assert_response :success
  end

  test "should destroy time_register" do
    assert_difference("TimeRegister.count", -1) do
      delete api_v1_time_register_url(@time_register), as: :json
    end

    assert_response :no_content
  end

  test "should return 404 for non-existent time_register" do
    get api_v1_time_register_url(id: 99999), as: :json
    assert_response :not_found
  end

  test "should return validation errors for invalid time_register" do
    post api_v1_time_registers_url, params: { 
      time_register: { 
        clock_in: "", 
        user_id: "" 
      } 
    }, as: :json
    assert_response :unprocessable_entity
  end
end