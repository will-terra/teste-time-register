class Api::V1::ReportsController < ApplicationController
  before_action :set_report_by_process_id, only: [:status, :download]

  # GET /api/v1/reports/:process_id/status
  def status
    render json: {
      process_id: @report.process_id,
      status: @report.status,
      progress: @report.progress,
      error_message: @report.error_message
    }
  end

  # GET /api/v1/reports/:process_id/download
  def download
    unless @report.completed?
      return render json: { 
        error: "Report is not ready for download. Current status: #{@report.status}" 
      }, status: :unprocessable_entity
    end

    unless @report.file_exists?
      return render json: { 
        error: 'Report file not found or has been cleaned up' 
      }, status: :not_found
    end

    send_file @report.file_path,
              type: 'text/csv',
              disposition: 'attachment',
              filename: generate_filename(@report)
  end

  private

  def set_report_by_process_id
    @report = Report.find_by!(process_id: params[:process_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Report not found' }, status: :not_found
  end

  def generate_filename(report)
    start_date = report.start_date.strftime('%Y%m%d')
    end_date = report.end_date.strftime('%Y%m%d')
    user_name = report.user.name.parameterize
    
    "relatorio_ponto_#{user_name}_#{start_date}_#{end_date}.csv"
  end
end