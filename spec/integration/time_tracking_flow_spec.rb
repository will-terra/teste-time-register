# spec/integration/time_tracking_flow_spec.rb

require 'rails_helper'

RSpec.describe 'Time Tracking Integration Flow', type: :request do
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }

  # Tests the complete user and time tracking workflow
  describe 'Complete user and time tracking workflow' do
    context 'new user registration and time tracking' do
      # Verifies the full lifecycle: user creation, time tracking, updates, and deletion
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

  # Tests concurrent time tracking for multiple users
  describe 'Multiple users time tracking scenarios' do
    let(:user1) { create(:user, name: 'Alice', email: 'alice@example.com') }
    let(:user2) { create(:user, name: 'Bob', email: 'bob@example.com') }

    # Verifies that multiple users can track time concurrently without interference
    it 'handles concurrent time tracking for multiple users' do
      # Setup: Two users are created for testing concurrent operations

      # Action: User 1 clocks in, creating an open time register
      user1_clock_in = {
        time_register: {
          user_id: user1.id,
          clock_in: 2.hours.ago.iso8601
        }
      }

      post '/api/v1/time_registers', params: user1_clock_in.to_json, headers: valid_headers
      expect(response).to have_http_status(:created)
      user1_register_id = JSON.parse(response.body)['id']

      # Action: User 2 clocks in, creating another open time register
      user2_clock_in = {
        time_register: {
          user_id: user2.id,
          clock_in: 1.hour.ago.iso8601
        }
      }

      post '/api/v1/time_registers', params: user2_clock_in.to_json, headers: valid_headers
      expect(response).to have_http_status(:created)
      user2_register_id = JSON.parse(response.body)['id']

      # Assert: Both users have open registers
      expect(user1.has_open_time_register?).to be true
      expect(user2.has_open_time_register?).to be true

      # Action: Retrieve all time registers
      get '/api/v1/time_registers'
      all_registers = JSON.parse(response.body)

      user1_entries = all_registers.select { |r| r['user_id'] == user1.id }
      user2_entries = all_registers.select { |r| r['user_id'] == user2.id }

      # Assert: The list includes entries for both users
      expect(user1_entries.size).to eq(1)
      expect(user2_entries.size).to eq(1)

      # Action: User 1 clocks out, closing their register
      clock_out_params = { time_register: { clock_out: 30.minutes.ago.iso8601 } }

      put "/api/v1/time_registers/#{user1_register_id}",
          params: clock_out_params.to_json,
          headers: valid_headers

      expect(response).to have_http_status(:success)

      # Assert: User 1 no longer has an open register, but User 2 does
      expect(user1.reload.has_open_time_register?).to be false
      expect(user2.reload.has_open_time_register?).to be true

      # Action: User 1 clocks in again, creating a new open register
      new_user1_clock_in = {
        time_register: {
          user_id: user1.id,
          clock_in: 15.minutes.ago.iso8601
        }
      }

      post '/api/v1/time_registers', params: new_user1_clock_in.to_json, headers: valid_headers
      expect(response).to have_http_status(:created)

      # Assert: Both users have open registers once more
      expect(user1.reload.has_open_time_register?).to be true
      expect(user2.reload.has_open_time_register?).to be true
    end
  end

  # Tests error handling and edge cases
  describe 'Error handling and edge cases' do
    let(:user) { create(:user) }

    # Verifies that various error scenarios are handled gracefully
    it 'handles various error scenarios gracefully' do
      # Test invalid user ID when creating time register
      invalid_user_params = {
        time_register: {
          user_id: 999999,
          clock_in: 1.hour.ago.iso8601
        }
      }

      post '/api/v1/time_registers', params: invalid_user_params.to_json, headers: valid_headers
      expect(response).to have_http_status(:unprocessable_content)

      # Test updating non-existent time register
      put '/api/v1/time_registers/999999',
          params: { time_register: { clock_out: 1.hour.ago.iso8601 } }.to_json,
          headers: valid_headers

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Time register not found')

      # Test accessing time registers for non-existent user
      get '/api/v1/users/999999/time_registers'
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('User not found')

      # Create valid time register for testing validation
      time_register = create(:time_register, :open, user: user)

      # Test setting clock_out before clock_in (validation error)
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

    # Verifies data consistency during complex operations
    it 'maintains data consistency during complex operations' do
      # Setup: Create user with existing closed time registers
      user_with_history = create(:user, :with_time_registers)
      initial_count = user_with_history.time_registers.count

      # Action: Create an open register for the user
      open_register = create(:time_register, :open, user: user_with_history)

      # Assert: User now has one more register and has an open one
      expect(user_with_history.time_registers.count).to eq(initial_count + 1)
      expect(user_with_history.has_open_time_register?).to be true

      # Action: Try to create another open register (should fail due to business rule)
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

      # Action: Close the open register
      put "/api/v1/time_registers/#{open_register.id}",
          params: { time_register: { clock_out: 15.minutes.ago.iso8601 } }.to_json,
          headers: valid_headers

      expect(response).to have_http_status(:success)

      # Action: Now create new open register (should succeed after closing previous)
      post '/api/v1/time_registers', params: duplicate_params.to_json, headers: valid_headers
      expect(response).to have_http_status(:created)

      # Assert: Final state - user has two more registers and one open
      user_with_history.reload
      expect(user_with_history.time_registers.count).to eq(initial_count + 2)
      expect(user_with_history.has_open_time_register?).to be true
    end
  end
end
