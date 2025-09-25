# spec/requests/api/v1/users_spec.rb

require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  let(:valid_attributes) { { name: 'John Doe', email: 'john@example.com' } }
  let(:invalid_attributes) { { name: '', email: 'invalid-email' } }
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }

  describe 'GET /api/v1/users' do
    it 'returns http success' do
      get '/api/v1/users'
      expect(response).to have_http_status(:success)
    end

    it 'returns empty array when no users exist' do
      get '/api/v1/users'
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq([])
    end

    it 'returns all users' do
      user1 = create(:user, name: 'John Doe', email: 'john@example.com')
      user2 = create(:user, name: 'Jane Smith', email: 'jane@example.com')

      get '/api/v1/users'
      
      expect(response).to have_http_status(:success)
      response_body = JSON.parse(response.body)
      expect(response_body.size).to eq(2)
      
      expect(response_body).to include(
        hash_including('name' => 'John Doe', 'email' => 'john@example.com'),
        hash_including('name' => 'Jane Smith', 'email' => 'jane@example.com')
      )
    end

    it 'includes user IDs in the response' do
      user = create(:user)
      
      get '/api/v1/users'
      
      response_body = JSON.parse(response.body)
      expect(response_body.first).to have_key('id')
      expect(response_body.first['id']).to eq(user.id)
    end
  end

  describe 'GET /api/v1/users/:id' do
    let(:user) { create(:user) }

    it 'returns the user' do
      get "/api/v1/users/#{user.id}"
      
      expect(response).to have_http_status(:success)
      response_body = JSON.parse(response.body)
      expect(response_body['id']).to eq(user.id)
      expect(response_body['name']).to eq(user.name)
      expect(response_body['email']).to eq(user.email)
    end

    it 'returns 404 when user does not exist' do
      get '/api/v1/users/999999'
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('User not found')
    end

    it 'returns 404 for invalid ID format' do
      get '/api/v1/users/invalid-id'
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('User not found')
    end
  end

  describe 'POST /api/v1/users' do
    it 'creates a new user with valid attributes' do
      expect {
        post '/api/v1/users', 
             params: { user: valid_attributes }.to_json, 
             headers: valid_headers
      }.to change(User, :count).by(1)
      
      expect(response).to have_http_status(:created)
      response_body = JSON.parse(response.body)
      expect(response_body['name']).to eq('John Doe')
      expect(response_body['email']).to eq('john@example.com')
    end

    it 'does not create user with invalid attributes' do
      expect {
        post '/api/v1/users', 
             params: { user: invalid_attributes }.to_json, 
             headers: valid_headers
      }.not_to change(User, :count)
      
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns validation errors for invalid attributes' do
      post '/api/v1/users', 
           params: { user: invalid_attributes }.to_json, 
           headers: valid_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body).to have_key('name')
      expect(response_body).to have_key('email')
    end

    it 'prevents duplicate emails' do
      create(:user, email: 'john@example.com')
      
      expect {
        post '/api/v1/users', 
             params: { user: valid_attributes }.to_json, 
             headers: valid_headers
      }.not_to change(User, :count)
      
      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body['email']).to include('has already been taken')
    end

    it 'handles missing user parameter' do
      post '/api/v1/users', 
           params: { name: 'John' }.to_json, 
           headers: valid_headers
      
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PUT /api/v1/users/:id' do
    let(:user) { create(:user) }
    let(:new_attributes) { { name: 'Updated Name', email: 'updated@example.com' } }

    it 'updates the user with valid attributes' do
      put "/api/v1/users/#{user.id}", 
          params: { user: new_attributes }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:success)
      user.reload
      expect(user.name).to eq('Updated Name')
      expect(user.email).to eq('updated@example.com')
    end

    it 'returns updated user data' do
      put "/api/v1/users/#{user.id}", 
          params: { user: new_attributes }.to_json, 
          headers: valid_headers
      
      response_body = JSON.parse(response.body)
      expect(response_body['name']).to eq('Updated Name')
      expect(response_body['email']).to eq('updated@example.com')
    end

    it 'does not update with invalid attributes' do
      original_name = user.name
      
      put "/api/v1/users/#{user.id}", 
          params: { user: invalid_attributes }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      user.reload
      expect(user.name).to eq(original_name)
    end

    it 'returns validation errors for invalid attributes' do
      put "/api/v1/users/#{user.id}", 
          params: { user: invalid_attributes }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body).to have_key('name')
      expect(response_body).to have_key('email')
    end

    it 'returns 404 when user does not exist' do
      put '/api/v1/users/999999', 
          params: { user: new_attributes }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('User not found')
    end
  end

  describe 'DELETE /api/v1/users/:id' do
    let!(:user) { create(:user) }

    it 'destroys the user' do
      expect {
        delete "/api/v1/users/#{user.id}"
      }.to change(User, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end

    it 'returns no content on successful deletion' do
      delete "/api/v1/users/#{user.id}"
      
      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end

    it 'returns 404 when user does not exist' do
      delete '/api/v1/users/999999'
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('User not found')
    end

    it 'destroys associated time registers' do
      user_with_registers = create(:user, :with_time_registers)
      
      expect {
        delete "/api/v1/users/#{user_with_registers.id}"
      }.to change(TimeRegister, :count).by(-3)
    end
  end

  describe 'GET /api/v1/users/:user_id/time_registers' do
    let(:user) { create(:user) }

    it 'returns user time registers' do
      register1 = create(:time_register, user: user, clock_in: 2.hours.ago)
      register2 = create(:time_register, user: user, clock_in: 1.hour.ago)
      
      get "/api/v1/users/#{user.id}/time_registers"
      
      expect(response).to have_http_status(:success)
      response_body = JSON.parse(response.body)
      expect(response_body.size).to eq(2)
    end

    it 'returns time registers ordered by clock_in' do
      register1 = create(:time_register, user: user, clock_in: 2.hours.ago)
      register2 = create(:time_register, user: user, clock_in: 4.hours.ago)
      register3 = create(:time_register, user: user, clock_in: 1.hour.ago)
      
      get "/api/v1/users/#{user.id}/time_registers"
      
      response_body = JSON.parse(response.body)
      clock_in_times = response_body.map { |r| Time.parse(r['clock_in']) }
      expect(clock_in_times).to eq(clock_in_times.sort)
    end

    it 'returns empty array for user with no time registers' do
      get "/api/v1/users/#{user.id}/time_registers"
      
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq([])
    end

    it 'does not return other users time registers' do
      other_user = create(:user)
      create(:time_register, user: other_user)
      create(:time_register, user: user)
      
      get "/api/v1/users/#{user.id}/time_registers"
      
      response_body = JSON.parse(response.body)
      expect(response_body.size).to eq(1)
      expect(response_body.first['user_id']).to eq(user.id)
    end

    it 'returns 404 when user does not exist' do
      get '/api/v1/users/999999/time_registers'
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('User not found')
    end
  end

  describe 'POST /api/v1/users/:user_id/reports' do
    include ActiveJob::TestHelper
    
    let(:user) { create(:user) }
    let(:valid_report_params) do
      {
        start_date: '2025-09-01',
        end_date: '2025-09-30'
      }
    end

    context 'with valid parameters' do
      it 'creates a new report request' do
        expect {
          post "/api/v1/users/#{user.id}/reports",
               params: valid_report_params.to_json,
               headers: valid_headers
        }.to change(Report, :count).by(1)
        
        expect(response).to have_http_status(:created)
      end

      it 'returns process_id and status' do
        post "/api/v1/users/#{user.id}/reports",
             params: valid_report_params.to_json,
             headers: valid_headers
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('process_id')
        expect(json_response).to have_key('status')
        expect(json_response['status']).to eq('queued')
        
        # Verifica se é um UUID válido
        uuid_pattern = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
        expect(json_response['process_id']).to match(uuid_pattern)
      end

      it 'enqueues ReportGenerationJob' do
        expect {
          post "/api/v1/users/#{user.id}/reports",
               params: valid_report_params.to_json,
               headers: valid_headers
        }.to have_enqueued_job(ReportGenerationJob)
      end

      it 'creates report with correct attributes' do
        post "/api/v1/users/#{user.id}/reports",
             params: valid_report_params.to_json,
             headers: valid_headers
        
        report = Report.last
        expect(report.user).to eq(user)
        expect(report.start_date).to eq(Date.parse('2025-09-01'))
        expect(report.end_date).to eq(Date.parse('2025-09-30'))
        expect(report.status).to eq('queued')
        expect(report.progress).to eq(0)
      end

      it 'handles same day start and end dates' do
        same_day_params = {
          start_date: '2025-09-15',
          end_date: '2025-09-15'
        }

        post "/api/v1/users/#{user.id}/reports",
             params: same_day_params.to_json,
             headers: valid_headers
        
        expect(response).to have_http_status(:created)
        report = Report.last
        expect(report.start_date).to eq(report.end_date)
      end
    end

    context 'with invalid parameters' do
      it 'returns bad request when start_date is missing' do
        invalid_params = { end_date: '2025-09-30' }
        
        post "/api/v1/users/#{user.id}/reports",
             params: invalid_params.to_json,
             headers: valid_headers
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('start_date and end_date are required')
      end

      it 'returns bad request when end_date is missing' do
        invalid_params = { start_date: '2025-09-01' }
        
        post "/api/v1/users/#{user.id}/reports",
             params: invalid_params.to_json,
             headers: valid_headers
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('start_date and end_date are required')
      end

      it 'returns bad request when both dates are missing' do
        post "/api/v1/users/#{user.id}/reports",
             params: {}.to_json,
             headers: valid_headers
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('start_date and end_date are required')
      end

      it 'returns bad request when end_date is before start_date' do
        invalid_params = {
          start_date: '2025-09-30',
          end_date: '2025-09-01'
        }
        
        post "/api/v1/users/#{user.id}/reports",
             params: invalid_params.to_json,
             headers: valid_headers
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('end_date must be after start_date')
      end

      it 'returns bad request for invalid date format' do
        invalid_params = {
          start_date: 'invalid-date',
          end_date: '2025-09-30'
        }
        
        post "/api/v1/users/#{user.id}/reports",
             params: invalid_params.to_json,
             headers: valid_headers
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid date format. Use YYYY-MM-DD format')
      end

      it 'does not create report when validation fails' do
        invalid_params = {
          start_date: '2025-09-30',
          end_date: '2025-09-01'
        }
        
        expect {
          post "/api/v1/users/#{user.id}/reports",
               params: invalid_params.to_json,
               headers: valid_headers
        }.not_to change(Report, :count)
      end

      it 'does not enqueue job when validation fails' do
        invalid_params = {
          start_date: '2025-09-30',
          end_date: '2025-09-01'
        }
        
        expect {
          post "/api/v1/users/#{user.id}/reports",
               params: invalid_params.to_json,
               headers: valid_headers
        }.not_to have_enqueued_job(ReportGenerationJob)
      end
    end

    context 'when user does not exist' do
      it 'returns not found error' do
        post '/api/v1/users/999999/reports',
             params: valid_report_params.to_json,
             headers: valid_headers
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('User not found')
      end

      it 'does not create report for non-existent user' do
        expect {
          post '/api/v1/users/999999/reports',
               params: valid_report_params.to_json,
               headers: valid_headers
        }.not_to change(Report, :count)
      end
    end

    context 'error handling' do
      before do
        # Simula um erro interno durante a criação do report
        allow_any_instance_of(User).to receive(:reports).and_raise(StandardError.new('Database error'))
      end

      it 'handles internal server errors gracefully' do
        expect(Rails.logger).to receive(:error).with(/Report creation failed/)
        
        post "/api/v1/users/#{user.id}/reports",
             params: valid_report_params.to_json,
             headers: valid_headers
        
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Internal server error')
      end
    end
  end
end