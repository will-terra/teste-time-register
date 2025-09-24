class Api::V1::UsersController < ApplicationController
  before_action :set_user, only: [:show, :update, :destroy, :time_registers]

  # GET /api/v1/users
  def index
    @users = User.all

    render json: @users
  end

  # GET /api/v1/users/:id
  def show
    render json: @user
  end

  # POST /api/v1/users
  def create
    @user = User.new(user_params)

    if @user.save
      render json: @user, status: :created
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/users/:id
  def update
    if @user.update(user_params)
      render json: @user
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/users/:id
  def destroy
    @user.destroy!
    head :no_content
  end

  # GET /api/v1/users/:id/time_registers
  def time_registers
    @time_registers = @user.time_registers.order(:clock_in)

    render json: @time_registers
  end

  private

  def set_user
    @user = User.find(params[:id] || params[:user_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end
end