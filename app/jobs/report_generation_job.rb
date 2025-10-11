require "csv"

class ReportGenerationJob < ApplicationJob
  queue_as :reports

  # Generates a time report in CSV format
  def perform(report_id)
    report = Report.find(report_id)

    begin
      # Updates status to processing
      report.update!(status: "processing", progress: 10)

      user = report.user
      time_registers = fetch_time_registers(user, report.start_date, report.end_date)

      # Updates progress
      report.update!(progress: 30)

      # Generates the CSV file
      csv_content = generate_csv_content(time_registers, user)

      # Updates progress
      report.update!(progress: 70)

      # Saves the file
      file_path = save_csv_file(csv_content, report.process_id)

      # Finishes successfully
      report.update!(
        status: "completed",
        progress: 100,
        file_path: file_path,
        error_message: nil
      )

    rescue StandardError => e
      Rails.logger.error "Report generation failed for report #{report.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      report.update!(
        status: "failed",
        error_message: e.message,
        progress: 0
      )

      raise e
    end
  end

  private

  # Fetches time registers for the user within the date range
  def fetch_time_registers(user, start_date, end_date)
    user.time_registers
        .where(clock_in: start_date.beginning_of_day..end_date.end_of_day)
        .order(:clock_in)
        .includes(:user)
  end

  # Generates CSV content with headers and data rows
  def generate_csv_content(time_registers, user)
    CSV.generate(headers: true) do |csv|
      # CSV header
      csv << [
        "Nome do Usuário",
        "Email",
        "Data",
        "Entrada",
        "Saída",
        "Horas Trabalhadas",
        "Status"
      ]

      time_registers.each do |register|
        csv << [
          user.name,
          user.email,
          register.clock_in.strftime("%d/%m/%Y"),
          register.clock_in.strftime("%H:%M:%S"),
          register.clock_out&.strftime("%H:%M:%S") || "Em andamento",
          calculate_worked_hours(register),
          register.clock_out.present? ? "Finalizado" : "Em andamento"
        ]
      end

      # Adds total line if there are records
      if time_registers.any?
        total_hours = calculate_total_hours(time_registers)
        csv << [ "", "", "", "", "", "Total: #{total_hours}", "" ]
      end
    end
  end

  # Calculates worked hours for a single register
  def calculate_worked_hours(register)
    return "0h 0m" unless register.clock_out

    duration = register.clock_out - register.clock_in
    hours = (duration / 1.hour).floor
    minutes = ((duration % 1.hour) / 1.minute).floor

    "#{hours}h #{minutes}m"
  end

  # Calculates total worked hours across all registers
  def calculate_total_hours(time_registers)
    total_seconds = time_registers.sum do |register|
      next 0 unless register.clock_out
      register.clock_out - register.clock_in
    end

    total_hours = (total_seconds / 1.hour).floor
    total_minutes = ((total_seconds % 1.hour) / 1.minute).floor

    "#{total_hours}h #{total_minutes}m"
  end

  # Saves the CSV content to a temporary file
  def save_csv_file(csv_content, process_id)
    # Stores files temporarily in tmp/reports/
    # These files are automatically managed by the system
    reports_dir = Rails.root.join("tmp", "reports")
    FileUtils.mkdir_p(reports_dir) unless Dir.exist?(reports_dir)

    # File name with timestamp to avoid collisions
    filename = "report_#{process_id}_#{Time.current.to_i}.csv"
    file_path = reports_dir.join(filename)

    # Writes the file
    File.write(file_path, csv_content)

    file_path.to_s
  end
end
