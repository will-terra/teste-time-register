require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should get index" do
    get api_v1_users_url, as: :json
    assert_response :success
  end

  test "should create user" do
    assert_difference("User.count") do
      post api_v1_users_url, params: { user: { email: "test@example.com", name: "Test User" } }, as: :json
    end

    assert_response :created
  end

  test "should show user" do
    get api_v1_user_url(@user), as: :json
    assert_response :success
  end

  test "should update user" do
    patch api_v1_user_url(@user), params: { user: { email: "updated@example.com", name: "Updated User" } }, as: :json
    assert_response :success
  end

  test "should destroy user" do
    assert_difference("User.count", -1) do
      delete api_v1_user_url(@user), as: :json
    end

    assert_response :no_content
  end

  test "should get user time registers" do
    get api_v1_user_time_registers_url(@user), as: :json
    assert_response :success
  end

  test "should return 404 for non-existent user" do
    get api_v1_user_url(id: 99999), as: :json
    assert_response :not_found
  end

  test "should return validation errors for invalid user" do
    post api_v1_users_url, params: { user: { email: "", name: "" } }, as: :json
    assert_response :unprocessable_entity
  end
end