# spec/integration/time_tracking_flow_spec.rb

require 'rails_helper'

RSpec.describe 'Time Tracking Integration Flow', type: :request do
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }

  describe 'Complete user and time tracking workflow' do
    context 'new user registration and time tracking' do
      it 'creates user, tracks time, and manages multiple time entries' do
        # Step 1: Create a new user
        user_params = { user: { name: 'John Doe', email: 'john@example.com' } }
        
        expect {
          post '/api/v1/users', params: user_params.to_json, headers: valid_headers
        }.to change(User, :count).by(1)
        
        expect(response).to have_http_status(:created)
        user_data = JSON.parse(response.body)
        user_id = user_data['id']
        
        # Step 2: Verify user creation
        get "/api/v1/users/#{user_id}"
        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['email']).to eq('john@example.com')
        
        # Step 3: User clocks in (first time entry)
        clock_in_params = { 
          time_register: { 
            user_id: user_id, 
            clock_in: 2.hours.ago.iso8601 
          } 
        }
        
        expect {
          post '/api/v1/time_registers', params: clock_in_params.to_json, headers: valid_headers
        }.to change(TimeRegister, :count).by(1)
        
        expect(response).to have_http_status(:created)
        first_entry_data = JSON.parse(response.body)
        first_entry_id = first_entry_data['id']
        
        # Step 4: Verify user has an open time register
        expect(User.find(user_id).has_open_time_register?).to be true
        
        # Step 5: Try to create another open register (should fail)
        expect {
          post '/api/v1/time_registers', params: clock_in_params.to_json, headers: valid_headers
        }.not_to change(TimeRegister, :count)
        
        expect(response).to have_http_status(:unprocessable_content)
        
        # Step 6: Clock out from first entry
        clock_out_params = { 
          time_register: { 
            clock_out: 1.hour.ago.iso8601 
          } 
        }
        
        put "/api/v1/time_registers/#{first_entry_id}", 
            params: clock_out_params.to_json, 
            headers: valid_headers
        
        expect(response).to have_http_status(:success)
        
        # Step 7: Verify user no longer has open time register
        expect(User.find(user_id).has_open_time_register?).to be false
        
        # Step 8: Create second time entry (different day)
        second_clock_in_params = { 
          time_register: { 
            user_id: user_id, 
            clock_in: 1.day.ago.beginning_of_day.iso8601,
            clock_out: 1.day.ago.end_of_day.iso8601
          } 
        }
        
        expect {
          post '/api/v1/time_registers', params: second_clock_in_params.to_json, headers: valid_headers
        }.to change(TimeRegister, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        # Step 9: Get user's time registers
        get "/api/v1/users/#{user_id}/time_registers"
        
        expect(response).to have_http_status(:success)
        user_registers = JSON.parse(response.body)
        expect(user_registers.size).to eq(2)
        
        # Verify chronological order
        clock_in_times = user_registers.map { |r| Time.parse(r['clock_in']) }
        expect(clock_in_times).to eq(clock_in_times.sort)
        
        # Step 10: Get all time registers (should include our user's entries)
        get '/api/v1/time_registers'
        
        expect(response).to have_http_status(:success)
        all_registers = JSON.parse(response.body)
        user_entries = all_registers.select { |r| r['user_id'] == user_id }
        expect(user_entries.size).to eq(2)
        
        # Step 11: Delete a time register
        expect {
          delete "/api/v1/time_registers/#{first_entry_id}"
        }.to change(TimeRegister, :count).by(-1)
        
        expect(response).to have_http_status(:no_content)
        
        # Step 12: Verify register was deleted
        get "/api/v1/users/#{user_id}/time_registers"
        remaining_registers = JSON.parse(response.body)
        expect(remaining_registers.size).to eq(1)
        
        # Step 13: Update user information
        update_params = { 
          user: { 
            name: 'John Smith', 
            email: 'john.smith@example.com' 
          } 
        }
        
        put "/api/v1/users/#{user_id}", 
            params: update_params.to_json, 
            headers: valid_headers
        
        expect(response).to have_http_status(:success)
        updated_user = JSON.parse(response.body)
        expect(updated_user['name']).to eq('John Smith')
        expect(updated_user['email']).to eq('john.smith@example.com')
        
        # Step 14: Delete user (should cascade delete remaining time registers)
        expect {
          delete "/api/v1/users/#{user_id}"
        }.to change(User, :count).by(-1)
         .and change(TimeRegister, :count).by(-1)
        
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'Multiple users time tracking scenarios' do
    let(:user1) { create(:user, name: 'Alice', email: 'alice@example.com') }
    let(:user2) { create(:user, name: 'Bob', email: 'bob@example.com') }

    it 'handles concurrent time tracking for multiple users' do
      # Both users can have open registers simultaneously
      
      # User 1 clocks in
      user1_clock_in = { 
        time_register: { 
          user_id: user1.id, 
          clock_in: 2.hours.ago.iso8601 
        } 
      }
      
      post '/api/v1/time_registers', params: user1_clock_in.to_json, headers: valid_headers
      expect(response).to have_http_status(:created)
      user1_register_id = JSON.parse(response.body)['id']
      
      # User 2 clocks in
      user2_clock_in = { 
        time_register: { 
          user_id: user2.id, 
          clock_in: 1.hour.ago.iso8601 
        } 
      }
      
      post '/api/v1/time_registers', params: user2_clock_in.to_json, headers: valid_headers
      expect(response).to have_http_status(:created)
      user2_register_id = JSON.parse(response.body)['id']
      
      # Both users should have open registers
      expect(user1.has_open_time_register?).to be true
      expect(user2.has_open_time_register?).to be true
      
      # Get all time registers - should show both users' entries
      get '/api/v1/time_registers'
      all_registers = JSON.parse(response.body)
      
      user1_entries = all_registers.select { |r| r['user_id'] == user1.id }
      user2_entries = all_registers.select { |r| r['user_id'] == user2.id }
      
      expect(user1_entries.size).to eq(1)
      expect(user2_entries.size).to eq(1)
      
      # User 1 clocks out
      clock_out_params = { time_register: { clock_out: 30.minutes.ago.iso8601 } }
      
      put "/api/v1/time_registers/#{user1_register_id}", 
          params: clock_out_params.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:success)
      
      # User 1 no longer has open register, User 2 still does
      expect(user1.reload.has_open_time_register?).to be false
      expect(user2.reload.has_open_time_register?).to be true
      
      # User 1 can now create another open register
      new_user1_clock_in = { 
        time_register: { 
          user_id: user1.id, 
          clock_in: 15.minutes.ago.iso8601 
        } 
      }
      
      post '/api/v1/time_registers', params: new_user1_clock_in.to_json, headers: valid_headers
      expect(response).to have_http_status(:created)
      
      # Now both users have open registers again
      expect(user1.reload.has_open_time_register?).to be true
      expect(user2.reload.has_open_time_register?).to be true
    end
  end

  describe 'Error handling and edge cases' do
    let(:user) { create(:user) }

    it 'handles various error scenarios gracefully' do
      # Try to create time register for non-existent user
      invalid_user_params = { 
        time_register: { 
          user_id: 999999, 
          clock_in: 1.hour.ago.iso8601 
        } 
      }
      
      post '/api/v1/time_registers', params: invalid_user_params.to_json, headers: valid_headers
      expect(response).to have_http_status(:unprocessable_content)
      
      # Try to update non-existent time register
      put '/api/v1/time_registers/999999', 
          params: { time_register: { clock_out: 1.hour.ago.iso8601 } }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Time register not found')
      
      # Try to get non-existent user's time registers
      get '/api/v1/users/999999/time_registers'
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('User not found')
      
      # Create valid time register
      time_register = create(:time_register, :open, user: user)
      
      # Try to set clock_out before clock_in
      invalid_update = { 
        time_register: { 
          clock_out: (time_register.clock_in - 1.hour).iso8601 
        } 
      }
      
      put "/api/v1/time_registers/#{time_register.id}", 
          params: invalid_update.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      response_body = JSON.parse(response.body)
      expect(response_body['clock_out']).to include('must be after clock in time')
      
      # Verify the register wasn't updated
      time_register.reload
      expect(time_register.clock_out).to be_nil
    end

    it 'maintains data consistency during complex operations' do
      # Create user with existing closed time registers
      user_with_history = create(:user, :with_time_registers)
      initial_count = user_with_history.time_registers.count
      
      # Create an open register
      open_register = create(:time_register, :open, user: user_with_history)
      
      # Verify total count
      expect(user_with_history.time_registers.count).to eq(initial_count + 1)
      expect(user_with_history.has_open_time_register?).to be true
      
      # Try to create another open register (should fail)
      duplicate_params = { 
        time_register: { 
          user_id: user_with_history.id, 
          clock_in: 30.minutes.ago.iso8601 
        } 
      }
      
      expect {
        post '/api/v1/time_registers', params: duplicate_params.to_json, headers: valid_headers
      }.not_to change(TimeRegister, :count)
      
      expect(response).to have_http_status(:unprocessable_content)
      
      # Close the open register
      put "/api/v1/time_registers/#{open_register.id}", 
          params: { time_register: { clock_out: 15.minutes.ago.iso8601 } }.to_json, 
          headers: valid_headers
      
      expect(response).to have_http_status(:success)
      
      # Now should be able to create new open register
      post '/api/v1/time_registers', params: duplicate_params.to_json, headers: valid_headers
      expect(response).to have_http_status(:created)
      
      # Verify final state
      user_with_history.reload
      expect(user_with_history.time_registers.count).to eq(initial_count + 2)
      expect(user_with_history.has_open_time_register?).to be true
    end
  end
end