# spec/requests/api/v1/reports_spec.rb

require 'rails_helper'

RSpec.describe 'Api::V1::Reports', type: :request do
  let(:user) { create(:user) }
  let(:report) { create(:report, user: user) }
  let(:process_id) { report.process_id }

  describe 'GET /api/v1/reports/:process_id/status' do
    context 'when report exists' do
      it 'returns report status information' do
        get "/api/v1/reports/#{process_id}/status"
        
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        
        json_response = JSON.parse(response.body)
        expect(json_response).to include(
          'process_id' => process_id,
          'status' => report.status,
          'progress' => report.progress,
          'error_message' => report.error_message
        )
      end

      context 'when report is queued' do
        let(:report) { create(:report, status: 'queued', progress: 0) }

        it 'returns queued status' do
          get "/api/v1/reports/#{process_id}/status"
          
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('queued')
          expect(json_response['progress']).to eq(0)
        end
      end

      context 'when report is processing' do
        let(:report) { create(:report, :processing) }

        it 'returns processing status with progress' do
          get "/api/v1/reports/#{process_id}/status"
          
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('processing')
          expect(json_response['progress']).to eq(50)
        end
      end

      context 'when report is completed' do
        let(:report) { create(:report, :completed) }

        it 'returns completed status' do
          get "/api/v1/reports/#{process_id}/status"
          
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('completed')
          expect(json_response['progress']).to eq(100)
          expect(json_response['error_message']).to be_nil
        end
      end

      context 'when report has failed' do
        let(:report) { create(:report, :failed) }

        it 'returns failed status with error message' do
          get "/api/v1/reports/#{process_id}/status"
          
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('failed')
          expect(json_response['progress']).to eq(0)
          expect(json_response['error_message']).to eq('Something went wrong during report generation')
        end
      end
    end

    context 'when report does not exist' do
      let(:invalid_process_id) { SecureRandom.uuid }

      it 'returns not found error' do
        get "/api/v1/reports/#{invalid_process_id}/status"
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Report not found')
      end
    end
  end

  describe 'GET /api/v1/reports/:process_id/download' do
    context 'when report is completed and file exists' do
      let(:report) { create(:report, :completed, :with_file, user: user) }

      it 'downloads the CSV file' do
        get "/api/v1/reports/#{process_id}/download"
        
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('text/csv')
        expect(response.headers['Content-Disposition']).to match(/attachment/)
        expect(response.headers['Content-Disposition']).to include('.csv')
      end

      it 'generates descriptive filename' do
        get "/api/v1/reports/#{process_id}/download"
        
        filename_pattern = /relatorio_ponto_.+_\d{8}_\d{8}\.csv/
        expect(response.headers['Content-Disposition']).to match(filename_pattern)
      end

      it 'returns CSV content' do
        get "/api/v1/reports/#{process_id}/download"
        
        expect(response.body).to include('Name,Email,Date')
        expect(response.body).to include('Test User,test@example.com')
      end
    end

    context 'when report is not completed' do
      context 'when report is queued' do
        let(:report) { create(:report, status: 'queued') }

        it 'returns unprocessable entity error' do
          get "/api/v1/reports/#{process_id}/download"
          
          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Report is not ready for download. Current status: queued')
        end
      end

      context 'when report is processing' do
        let(:report) { create(:report, :processing) }

        it 'returns unprocessable entity error' do
          get "/api/v1/reports/#{process_id}/download"
          
          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Report is not ready for download. Current status: processing')
        end
      end

      context 'when report has failed' do
        let(:report) { create(:report, :failed) }

        it 'returns unprocessable entity error' do
          get "/api/v1/reports/#{process_id}/download"
          
          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Report is not ready for download. Current status: failed')
        end
      end
    end

    context 'when report is completed but file does not exist' do
      let(:report) { create(:report, :completed) }

      before do
        # Simula arquivo que foi removido/não existe
        report.update!(file_path: '/non/existent/path.csv')
      end

      it 'returns not found error' do
        get "/api/v1/reports/#{process_id}/download"
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Report file not found or has been cleaned up')
      end
    end

    context 'when report does not exist' do
      let(:invalid_process_id) { SecureRandom.uuid }

      it 'returns not found error' do
        get "/api/v1/reports/#{invalid_process_id}/download"
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Report not found')
      end
    end
  end

  describe 'filename generation' do
    let(:report) do 
      create(:report, :completed, :with_file, 
             user: user, 
             start_date: Date.new(2025, 9, 1), 
             end_date: Date.new(2025, 9, 30))
    end

    before do
      user.update!(name: 'João da Silva')
    end

    it 'generates filename with user name and date range' do
      get "/api/v1/reports/#{process_id}/download"
      
      disposition = response.headers['Content-Disposition']
      expect(disposition).to include('relatorio_ponto_joao-da-silva_20250901_20250930.csv')
    end
  end
end