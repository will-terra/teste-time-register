class TimeRegistersController < ApplicationController
  before_action :set_time_register, only: %i[ show update destroy ]

  # GET /time_registers
  def index
    @time_registers = TimeRegister.all

    render json: @time_registers
  end

  # GET /time_registers/1
  def show
    render json: @time_register
  end

  # POST /time_registers
  def create
    @time_register = TimeRegister.new(time_register_params)

    if @time_register.save
      render json: @time_register, status: :created, location: @time_register
    else
      render json: @time_register.errors, status: :unprocessable_content
    end
  end

  # PATCH/PUT /time_registers/1
  def update
    if @time_register.update(time_register_params)
      render json: @time_register
    else
      render json: @time_register.errors, status: :unprocessable_content
    end
  end

  # DELETE /time_registers/1
  def destroy
    @time_register.destroy!
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_time_register
      @time_register = TimeRegister.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def time_register_params
      params.expect(time_register: [ :user_id, :clock_in, :clock_out ])
    end
end
