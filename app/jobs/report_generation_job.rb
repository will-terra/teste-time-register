require 'csv'

class ReportGenerationJob < ApplicationJob
  queue_as :reports

  # Gera um relatório de ponto em formato CSV
  def perform(report_id)
    report = Report.find(report_id)
    
    begin
      # Atualiza status para processing
      report.update!(status: 'processing', progress: 10)
      
      user = report.user
      time_registers = fetch_time_registers(user, report.start_date, report.end_date)
      
      # Atualiza progresso
      report.update!(progress: 30)
      
      # Gera o arquivo CSV
      csv_content = generate_csv_content(time_registers, user)
      
      # Atualiza progresso
      report.update!(progress: 70)
      
      # Salva o arquivo
      file_path = save_csv_file(csv_content, report.process_id)
      
      # Finaliza com sucesso
      report.update!(
        status: 'completed', 
        progress: 100, 
        file_path: file_path,
        error_message: nil
      )
      
    rescue StandardError => e
      Rails.logger.error "Report generation failed for report #{report.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      report.update!(
        status: 'failed',
        error_message: e.message,
        progress: 0
      )
      
      raise e
    end
  end

  private

  def fetch_time_registers(user, start_date, end_date)
    user.time_registers
        .where(clock_in: start_date.beginning_of_day..end_date.end_of_day)
        .order(:clock_in)
        .includes(:user)
  end

  def generate_csv_content(time_registers, user)
    CSV.generate(headers: true) do |csv|
      # Cabeçalho do CSV
      csv << [
        'Nome do Usuário',
        'Email',
        'Data',
        'Entrada',
        'Saída',
        'Horas Trabalhadas',
        'Status'
      ]

      time_registers.each do |register|
        csv << [
          user.name,
          user.email,
          register.clock_in.strftime('%d/%m/%Y'),
          register.clock_in.strftime('%H:%M:%S'),
          register.clock_out&.strftime('%H:%M:%S') || 'Em andamento',
          calculate_worked_hours(register),
          register.clock_out.present? ? 'Finalizado' : 'Em andamento'
        ]
      end

      # Adiciona linha de totais se houver registros
      if time_registers.any?
        total_hours = calculate_total_hours(time_registers)
        csv << ['', '', '', '', '', "Total: #{total_hours}", '']
      end
    end
  end

  def calculate_worked_hours(register)
    return '0h 0m' unless register.clock_out

    duration = register.clock_out - register.clock_in
    hours = (duration / 1.hour).floor
    minutes = ((duration % 1.hour) / 1.minute).floor
    
    "#{hours}h #{minutes}m"
  end

  def calculate_total_hours(time_registers)
    total_seconds = time_registers.sum do |register|
      next 0 unless register.clock_out
      register.clock_out - register.clock_in
    end

    total_hours = (total_seconds / 1.hour).floor
    total_minutes = ((total_seconds % 1.hour) / 1.minute).floor
    
    "#{total_hours}h #{total_minutes}m"
  end

  def save_csv_file(csv_content, process_id)
    # Armazena arquivos temporariamente em tmp/reports/
    # Estes arquivos são automaticamente gerenciados pelo sistema
    reports_dir = Rails.root.join('tmp', 'reports')
    FileUtils.mkdir_p(reports_dir) unless Dir.exist?(reports_dir)

    # Nome do arquivo com timestamp para evitar colisões
    filename = "report_#{process_id}_#{Time.current.to_i}.csv"
    file_path = reports_dir.join(filename)

    # Escreve o arquivo
    File.write(file_path, csv_content)
    
    file_path.to_s
  end
end