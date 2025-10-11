# spec/integration/report_generation_flow_spec.rb

require 'rails_helper'

RSpec.describe 'Report Generation Flow', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, name: 'João Silva', email: 'joao@empresa.com') }
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }

  before do
    # Creates some time registers for the user to test report generation
    create(:time_register,
           user: user,
           clock_in: Date.yesterday.beginning_of_day + 8.hours,
           clock_out: Date.yesterday.beginning_of_day + 17.hours)

    create(:time_register,
           user: user,
           clock_in: Date.yesterday.beginning_of_day + 9.hours,
           clock_out: Date.yesterday.beginning_of_day + 18.hours)

    # Cleans reports directory before each test
    FileUtils.rm_rf(Rails.root.join('tmp', 'reports'))
  end

  after do
    # Cleans files created during tests after each test
    FileUtils.rm_rf(Rails.root.join('tmp', 'reports'))
  end

  # Tests the complete report generation workflow from request to download
  describe 'complete report generation workflow' do
    # Verifies the full flow: request -> queue -> process -> complete -> download
    it 'successfully generates and downloads a report' do
      # 1. Request report generation
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: 1.week.ago.to_date.to_s,
             end_date: Date.current.to_s
           }.to_json,
           headers: valid_headers

      expect(response).to have_http_status(:created)

      response_data = JSON.parse(response.body)
      process_id = response_data['process_id']
      expect(process_id).to be_present
      expect(response_data['status']).to eq('queued')

      # 2. Check initial status (queued)
      get "/api/v1/reports/#{process_id}/status"
      expect(response).to have_http_status(:ok)

      status_data = JSON.parse(response.body)
      expect(status_data['status']).to eq('queued')
      expect(status_data['progress']).to eq(0)

      # 3. Execute the job (simulates background processing)
      perform_enqueued_jobs

      # 4. Check status after processing (completed)
      get "/api/v1/reports/#{process_id}/status"
      expect(response).to have_http_status(:ok)

      final_status = JSON.parse(response.body)
      expect(final_status['status']).to eq('completed')
      expect(final_status['progress']).to eq(100)
      expect(final_status['error_message']).to be_nil

      # 5. Download the report
      get "/api/v1/reports/#{process_id}/download"
      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('text/csv')

      # Verifies CSV content
      csv_content = response.body.force_encoding('UTF-8')
      expect(csv_content).to include('João Silva')
      expect(csv_content).to include('joao@empresa.com')
      expect(csv_content).to include('Total:')
      expect(csv_content.lines.count).to eq(4) # Header + 2 data rows + total row
    end

    # Verifies that errors during generation are handled gracefully
    it 'handles errors gracefully during generation' do
      # Simulates an error during report generation
      allow(File).to receive(:write).and_raise(StandardError.new('Disk full'))

      # Requests report generation
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: 1.week.ago.to_date.to_s,
             end_date: Date.current.to_s
           }.to_json,
           headers: valid_headers

      process_id = JSON.parse(response.body)['process_id']

      # Executes the job (which will fail)
      expect {
        perform_enqueued_jobs
      }.to raise_error(StandardError, 'Disk full')

      # Verifies that status was updated to failed
      get "/api/v1/reports/#{process_id}/status"

      status_data = JSON.parse(response.body)
      expect(status_data['status']).to eq('failed')
      expect(status_data['error_message']).to eq('Disk full')
      expect(status_data['progress']).to eq(0)

      # Download attempt should fail
      get "/api/v1/reports/#{process_id}/download"
      expect(response).to have_http_status(:unprocessable_content)
    end

    # Verifies that empty reports are generated when no data exists
    it 'generates empty report when user has no time registers in period' do
      # Removes existing registers
      user.time_registers.destroy_all

      # Requests report generation
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: 1.week.ago.to_date.to_s,
             end_date: Date.current.to_s
           }.to_json,
           headers: valid_headers

      process_id = JSON.parse(response.body)['process_id']

      # Executes the job
      perform_enqueued_jobs

      # Verifies that it was completed
      get "/api/v1/reports/#{process_id}/status"
      expect(JSON.parse(response.body)['status']).to eq('completed')

      # Downloads and verifies empty content
      get "/api/v1/reports/#{process_id}/download"
      csv_content = response.body.force_encoding('UTF-8')

      lines = csv_content.strip.split("\n")
      expect(lines.length).to eq(1) # Only header
      expect(lines.first).to include('Nome do Usuário,Email,Data,Entrada,Saída,Horas Trabalhadas,Status')
    end

    # Verifies that downloads are prevented before report completion
    it 'prevents download before completion' do
      # Requests report generation
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: 1.week.ago.to_date.to_s,
             end_date: Date.current.to_s
           }.to_json,
           headers: valid_headers

      process_id = JSON.parse(response.body)['process_id']

      # Tries to download before processing
      get "/api/v1/reports/#{process_id}/download"
      expect(response).to have_http_status(:unprocessable_content)

      error_data = JSON.parse(response.body)
      expect(error_data['error']).to include('Report is not ready for download')
    end
  end

  # Tests various validation scenarios for report generation
  describe 'validation scenarios' do
    # Verifies that end_date before start_date is rejected
    it 'validates date parameters' do
      # End date before start date
      post "/api/v1/users/#{user.id}/reports",
           params: {
             start_date: Date.current.to_s,
             end_date: 1.week.ago.to_date.to_s
           }.to_json,
           headers: valid_headers

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to eq('end_date must be after start_date')
    end

    # Verifies that required parameters are enforced
    it 'validates required parameters' do
      # Missing parameters
      post "/api/v1/users/#{user.id}/reports",
           params: {}.to_json,
           headers: valid_headers

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to eq('start_date and end_date are required')
    end

    # Verifies that non-existent users return 404
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
