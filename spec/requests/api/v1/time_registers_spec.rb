# spec/requests/api/v1/time_registers_spec.rb

require 'rails_helper'

RSpec.describe 'Api::V1::TimeRegisters', type: :request do
  let(:user) { create(:user) }
  let(:valid_attributes) { 
    { 
      user_id: user.id, 
      clock_in: 2.hours.ago.iso8601, 
      clock_out: 1.hour.ago.iso8601 
    } 
  }
  let(:valid_open_attributes) { 
    { 
      user_id: user.id, 
      clock_in: 1.hour.ago.iso8601 
    } 
  }
  let(:invalid_attributes) { { user_id: nil, clock_in: nil } }
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }

  describe 'GET /api/v1/time_registers' do
    it 'returns http success' do
      get '/api/v1/time_registers'
      expect(response).to have_http_status(:success)
    end

    it 'returns empty array when no time registers exist' do
      get '/api/v1/time_registers'
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq([])
    end

    it 'returns all time registers' do
      register1 = create(:time_register, user: user)
      register2 = create(:time_register, user: user)

      get '/api/v1/time_registers'
      
      expect(response).to have_http_status(:success)
      response_body = JSON.parse(response.body)
      expect(response_body.size).to eq(2)
    end

    it 'returns time registers ordered by clock_in' do
      register1 = create(:time_register, clock_in: 3.hours.ago, user: user)
      register2 = create(:time_register, clock_in: 1.hour.ago, user: user)
      register3 = create(:time_register, clock_in: 2.hours.ago, user: user)

      get '/api/v1/time_registers'
      
      response_body = JSON.parse(response.body)
      clock_in_times = response_body.map { |r| Time.parse(r['clock_in']) }
      expect(clock_in_times).to eq(clock_in_times.sort)
    end

    it 'includes user information through association' do
      register = create(:time_register, user: user)
      
      get '/api/v1/time_registers'
      
      response_body = JSON.parse(response.body)
      expect(response_body.first['user_id']).to eq(user.id)
    end
  end

  describe 'GET /api/v1/time_registers/:id' do
    let(:time_register) { create(:time_register, user: user) }

    it 'returns the time register' do
      get "/api/v1/time_registers/#{time_register.id}"
      
      expect(response).to have_http_status(:success)
      response_body = JSON.parse(response.body)
      expect(response_body['id']).to eq(time_register.id)
      expect(response_body['user_id']).to eq(user.id)
    end

    it 'includes clock_in and clock_out times' do
      get "/api/v1/time_registers/#{time_register.id}"
      
      response_body = JSON.parse(response.body)
      expect(response_body).to have_key('clock_in')
      expect(response_body).to have_key('clock_out')
    end

    it 'returns 404 when time register does not exist' do
      get '/api/v1/time_registers/999999'
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Time register not found')
    end

    it 'returns 404 for invalid ID format' do
      get '/api/v1/time_registers/invalid-id'
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Time register not found')
    end
  end

  describe 'POST /api/v1/time_registers' do
    it 'creates a new time register with valid attributes' do
      expect {
        post '/api/v1/time_registers', 
             params: { time_register: valid_attributes }.to_json, 
             headers: valid_headers
      }.to change(TimeRegister, :count).by(1)
      
      expect(response).to have_http_status(:created)
      response_body = JSON.parse(response.body)
      expect(response_body['user_id']).to eq(user.id)
    end

    it 'creates an open time register' do
      expect {
        post '/api/v1/time_registers', 
             params: { time_register: valid_open_attributes }.to_json, 
             headers: valid_headers
      }.to change(TimeRegister, :count).by(1)
      
      expect(response).to have_http_status(:created)
      response_body = JSON.parse(response.body)
      expect(response_body['user_id']).to eq(user.id)
      expect(response_body['clock_out']).to be_nil
    end

    it 'does not create time register with invalid attributes' do
      expect {
        post '/api/v1/time_registers', 
             params: { time_register: invalid_attributes }.to_json, 
             headers: valid_headers
      }.not_to change(TimeRegister, :count)
      
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns validation errors for invalid attributes' do
      post '/api/v1/time_registers', 
           params: { time_register: invalid_attributes }.to_json, 
           headers: valid_headers
      
      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body).to have_key('clock_in')
      expect(response_body).to have_key('user')
    end

    it 'prevents multiple open registers for the same user' do
      create(:time_register, :open, user: user)
      
      expect {
        post '/api/v1/time_registers', 
             params: { time_register: valid_open_attributes }.to_json, 
             headers: valid_headers
      }.not_to change(TimeRegister, :count)
      
      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body['base']).to include('User already has an open time register')
    end

    it 'prevents clock_out before clock_in' do
      invalid_times = { 
        user_id: user.id, 
        clock_in: 1.hour.ago.iso8601, 
        clock_out: 2.hours.ago.iso8601 
      }
      
      expect {
        post '/api/v1/time_registers', 
             params: { time_register: invalid_times }.to_json, 
             headers: valid_headers
      }.not_to change(TimeRegister, :count)
      
      expect(response).to have_http_status(:unprocessable_entity)
      response_body = JSON.parse(response.body)
      expect(response_body['clock_out']).to include('must be after clock in time')
    end

    it 'handles missing time_register parameter' do
      post '/api/v1/time_registers', 
           params: { user_id: user.id }.to_json, 
           headers: valid_headers
      
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PUT /api/v1/time_registers/:id' do
    let(:time_register) { create(:time_register, :open, user: user) }
    let(:update_attributes) { { clock_out: 1.hour.ago.iso8601 } }

    it 'updates the time register with valid attributes' do
      put "/api/v1/time_registers/#{time_register.id}", 
          params: { time_register: update_attributes }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:success)
      time_register.reload
      expect(time_register.clock_out).not_to be_nil
    end

    it 'returns updated time register data' do
      put "/api/v1/time_registers/#{time_register.id}", 
          params: { time_register: update_attributes }.to_json, 
          headers: valid_headers
      
      response_body = JSON.parse(response.body)
      expect(response_body['clock_out']).not_to be_nil
      expect(Time.parse(response_body['clock_out'])).to be_within(1.second).of(1.hour.ago)
    end

    it 'can update clock_in time' do
      new_clock_in = 3.hours.ago.iso8601
      
      put "/api/v1/time_registers/#{time_register.id}", 
          params: { time_register: { clock_in: new_clock_in } }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:success)
      time_register.reload
      expect(time_register.clock_in).to be_within(1.second).of(3.hours.ago)
    end

    it 'does not update with invalid attributes' do
      original_clock_in = time_register.clock_in
      invalid_update = { clock_in: nil } # Invalid - missing clock_in
      
      put "/api/v1/time_registers/#{time_register.id}", 
          params: { time_register: invalid_update }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      time_register.reload
      expect(time_register.clock_in).to eq(original_clock_in)
      expect(time_register.clock_out).to be_nil
    end

    it 'returns validation errors for invalid attributes' do
      invalid_update = { clock_in: nil } # Invalid - missing clock_in
      
      put "/api/v1/time_registers/#{time_register.id}", 
          params: { time_register: invalid_update }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      response_body = JSON.parse(response.body)
      expect(response_body['clock_in']).to include("can't be blank")
    end

    it 'returns 404 when time register does not exist' do
      put '/api/v1/time_registers/999999', 
          params: { time_register: update_attributes }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Time register not found')
    end
  end

  describe 'DELETE /api/v1/time_registers/:id' do
    let!(:time_register) { create(:time_register, user: user) }

    it 'destroys the time register' do
      expect {
        delete "/api/v1/time_registers/#{time_register.id}"
      }.to change(TimeRegister, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end

    it 'returns no content on successful deletion' do
      delete "/api/v1/time_registers/#{time_register.id}"
      
      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end

    it 'returns 404 when time register does not exist' do
      delete '/api/v1/time_registers/999999'
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Time register not found')
    end

    it 'allows deleting open time registers' do
      open_register = create(:time_register, :open, user: user)
      
      expect {
        delete "/api/v1/time_registers/#{open_register.id}"
      }.to change(TimeRegister, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'edge cases and business logic' do
    it 'handles user with multiple closed registers' do
      create_list(:time_register, 3, :closed, user: user)
      
      # Should be able to create another closed register
      expect {
        post '/api/v1/time_registers', 
             params: { time_register: valid_attributes }.to_json, 
             headers: valid_headers
      }.to change(TimeRegister, :count).by(1)
      
      expect(response).to have_http_status(:created)
    end

    it 'allows creating open register after closing previous one' do
      open_register = create(:time_register, :open, user: user)
      
      # Close the register
      put "/api/v1/time_registers/#{open_register.id}", 
          params: { time_register: { clock_out: 1.hour.ago.iso8601 } }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:success)
      
      # Now should be able to create another open register
      expect {
        post '/api/v1/time_registers', 
             params: { time_register: valid_open_attributes }.to_json, 
             headers: valid_headers
      }.to change(TimeRegister, :count).by(1)
      
      expect(response).to have_http_status(:created)
    end
  end
end