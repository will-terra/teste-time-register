class Api::V1::TimeRegistersController < ApplicationController
  before_action :set_time_register, only: [:show, :update, :destroy]

  # GET /api/v1/time_registers
  def index
    @time_registers = TimeRegister.all.includes(:user).order(:clock_in)

    render json: @time_registers
  end

  # GET /api/v1/time_registers/:id
  def show
    render json: @time_register
  end

  # POST /api/v1/time_registers
  def create
    @time_register = TimeRegister.new(time_register_params)

    if @time_register.save
      render json: @time_register, status: :created
    else
      render json: @time_register.errors, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/time_registers/:id
  def update
    if @time_register.update(time_register_params)
      render json: @time_register
    else
      render json: @time_register.errors, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/time_registers/:id
  def destroy
    @time_register.destroy!
    head :no_content
  end

  private

  def set_time_register
    @time_register = TimeRegister.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Time register not found' }, status: :not_found
  end

  def time_register_params
    params.require(:time_register).permit(:user_id, :clock_in, :clock_out)
  end
end