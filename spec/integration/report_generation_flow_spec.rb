# spec/integration/report_generation_flow_spec.rb

require 'rails_helper'

RSpec.describe 'Report Generation Flow', type: :request do
  include ActiveJob::TestHelper
  
  let(:user) { create(:user, name: 'João Silva', email: 'joao@empresa.com') }
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }

  before do
    # Cria alguns registros de ponto para o usuário
    create(:time_register, 
           user: user, 
           clock_in: 2.days.ago.beginning_of_day + 8.hours,
           clock_out: 2.days.ago.beginning_of_day + 17.hours)
    
    create(:time_register, 
           user: user, 
           clock_in: 1.day.ago.beginning_of_day + 9.hours,
           clock_out: 1.day.ago.beginning_of_day + 18.hours)
    
    # Limpa diretório de relatórios
    FileUtils.rm_rf(Rails.root.join('tmp', 'reports'))
  end

  after do
    # Limpa arquivos criados durante os testes
    FileUtils.rm_rf(Rails.root.join('tmp', 'reports'))
  end

  describe 'complete report generation workflow' do
    it 'successfully generates and downloads a report' do
      # 1. Solicita geração do relatório
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: 7.days.ago.to_date.to_s,
             end_date: Date.current.to_s
           }.to_json,
           headers: valid_headers

      expect(response).to have_http_status(:created)
      
      response_data = JSON.parse(response.body)
      process_id = response_data['process_id']
      expect(process_id).to be_present
      expect(response_data['status']).to eq('queued')

      # 2. Verifica status inicial (queued)
      get "/api/v1/reports/#{process_id}/status"
      expect(response).to have_http_status(:ok)
      
      status_data = JSON.parse(response.body)
      expect(status_data['status']).to eq('queued')
      expect(status_data['progress']).to eq(0)

      # 3. Executa o job (simula processamento em background)
      perform_enqueued_jobs

      # 4. Verifica status após processamento (completed)
      get "/api/v1/reports/#{process_id}/status"
      expect(response).to have_http_status(:ok)
      
      final_status = JSON.parse(response.body)
      expect(final_status['status']).to eq('completed')
      expect(final_status['progress']).to eq(100)
      expect(final_status['error_message']).to be_nil

      # 5. Faz download do relatório
      get "/api/v1/reports/#{process_id}/download"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('text/csv')
      
      # Verifica conteúdo do CSV
      csv_content = response.body.force_encoding('UTF-8')
      expect(csv_content).to include('Nome do Usuário,Email,Data,Entrada,Saída,Horas Trabalhadas,Status')
      expect(csv_content).to include('João Silva')
      expect(csv_content).to include('joao@empresa.com')
      expect(csv_content).to include('9h 0m') # Horas trabalhadas
      expect(csv_content).to include('Total: 18h 0m') # Total de horas

      # 6. Verifica que arquivo foi criado no sistema de arquivos
      report = Report.find_by(process_id: process_id)
      expect(report.file_exists?).to be true
      expect(File.exist?(report.file_path)).to be true
    end

    it 'handles errors gracefully during generation' do
      # Simula erro durante geração
      allow(File).to receive(:write).and_raise(StandardError.new('Disk full'))

      # Solicita relatório
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: 1.week.ago.to_date.to_s,
             end_date: Date.current.to_s
           }.to_json,
           headers: valid_headers

      process_id = JSON.parse(response.body)['process_id']

      # Executa job (que falhará)
      expect {
        perform_enqueued_jobs
      }.to raise_error(StandardError, 'Disk full')

      # Verifica que status foi atualizado para failed
      get "/api/v1/reports/#{process_id}/status"
      
      status_data = JSON.parse(response.body)
      expect(status_data['status']).to eq('failed')
      expect(status_data['error_message']).to eq('Disk full')
      expect(status_data['progress']).to eq(0)

      # Tentativa de download deve falhar
      get "/api/v1/reports/#{process_id}/download"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'generates empty report when user has no time registers in period' do
      # Remove registros existentes
      user.time_registers.destroy_all

      # Solicita relatório
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: 1.week.ago.to_date.to_s,
             end_date: Date.current.to_s
           }.to_json,
           headers: valid_headers

      process_id = JSON.parse(response.body)['process_id']

      # Executa job
      perform_enqueued_jobs

      # Verifica que foi completado
      get "/api/v1/reports/#{process_id}/status"
      expect(JSON.parse(response.body)['status']).to eq('completed')

      # Faz download e verifica conteúdo vazio
      get "/api/v1/reports/#{process_id}/download"
      csv_content = response.body.force_encoding('UTF-8')
      
      lines = csv_content.strip.split("\n")
      expect(lines.length).to eq(1) # Apenas cabeçalho
      expect(lines.first).to include('Nome do Usuário,Email,Data,Entrada,Saída,Horas Trabalhadas,Status')
    end

    it 'prevents download before completion' do
      # Solicita relatório
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: 1.week.ago.to_date.to_s,
             end_date: Date.current.to_s
           }.to_json,
           headers: valid_headers

      process_id = JSON.parse(response.body)['process_id']

      # Tenta download antes do processamento
      get "/api/v1/reports/#{process_id}/download"
      expect(response).to have_http_status(:unprocessable_entity)
      
      error_data = JSON.parse(response.body)
      expect(error_data['error']).to include('Report is not ready for download')
    end
  end

  describe 'validation scenarios' do
    it 'validates date parameters' do
      # Data final antes da inicial
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: Date.current.to_s,
             end_date: 1.week.ago.to_date.to_s
           }.to_json,
           headers: valid_headers

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to eq('end_date must be after start_date')
    end

    it 'validates required parameters' do
      # Parâmetros ausentes
      post "/api/v1/users/#{user.id}/reports",
           params: {}.to_json,
           headers: valid_headers

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to eq('start_date and end_date are required')
    end

    it 'validates user existence' do
      post '/api/v1/users/99999/reports',
           params: {
             start_date: 1.week.ago.to_date.to_s,
             end_date: Date.current.to_s
           }.to_json,
           headers: valid_headers

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('User not found')
    end
  end
end