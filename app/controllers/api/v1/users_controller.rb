class Api::V1::UsersController < ApplicationController
  before_action :set_user, only: [:show, :update, :destroy, :time_registers, :reports]

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

  # POST /api/v1/users/:id/reports
  def reports
    unless valid_report_params?
      return render json: { error: 'start_date and end_date are required' }, status: :bad_request
    end

    # Validação das datas
    start_date = Date.parse(params[:start_date])
    end_date = Date.parse(params[:end_date])
    
    if end_date < start_date
      return render json: { error: 'end_date must be after start_date' }, status: :bad_request
    end

    # Cria o registro do relatório
    report = @user.reports.build(
      start_date: start_date,
      end_date: end_date
    )

    if report.save
      # Agenda o job para gerar o relatório
      ReportGenerationJob.perform_later(report.id)
      
      render json: {
        process_id: report.process_id,
        status: report.status
      }, status: :created
    else
      render json: report.errors, status: :unprocessable_entity
    end

  rescue Date::Error
    render json: { error: 'Invalid date format. Use YYYY-MM-DD format' }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error "Report creation failed: #{e.message}"
    render json: { error: 'Internal server error' }, status: :internal_server_error
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

  def valid_report_params?
    params[:start_date].present? && params[:end_date].present?
  end
end