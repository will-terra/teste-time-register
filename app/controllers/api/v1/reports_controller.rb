# Controller for managing report status and downloads
class Api::V1::ReportsController < ApplicationController
  # Sets the report instance variable before status and download actions
  before_action :set_report_by_process_id, only: [ :status, :download ]

  # GET /api/v1/reports/:process_id/status
  # Returns the current status, progress, and any error message for a report
  def status
    render json: {
      process_id: @report.process_id,
      status: @report.status,
      progress: @report.progress,
      error_message: @report.error_message
    }
  end

  # GET /api/v1/reports/:process_id/download
  # Downloads the generated CSV report if the report is completed and the file exists
  def download
    # Check if the report is completed
    unless @report.completed?
      return render json: {
        error: "Report is not ready for download. Current status: #{@report.status}"
      }, status: :unprocessable_entity
    end

    # Check if the report file exists
    unless @report.file_exists?
      return render json: {
        error: "Report file not found or has been cleaned up"
      }, status: :not_found
    end

    # Validate file path is within allowed directory to prevent path traversal
    allowed_dir = Rails.root.join("tmp", "reports")
    unless Pathname.new(@report.file_path).expand_path.to_s.start_with?(allowed_dir.expand_path.to_s)
      return render json: { error: "Invalid file path" }, status: :forbidden
    end

    # Send the file as an attachment
    send_file @report.file_path,
              type: "text/csv",
              disposition: "attachment",
              filename: generate_filename(@report)
  end

  private

  # Finds the report by process_id parameter, raises 404 if not found
  def set_report_by_process_id
    @report = Report.find_by!(process_id: params[:process_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Report not found" }, status: :not_found
  end

  # Generates a filename for the CSV report including user name and date range
  def generate_filename(report)
    start_date = report.start_date.strftime("%Y%m%d")
    end_date = report.end_date.strftime("%Y%m%d")
    user_name = report.user.name.parameterize
    "relatorio_ponto_#{user_name}_#{start_date}_#{end_date}.csv"
  end
end
