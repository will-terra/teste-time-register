# spec/models/time_register_spec.rb

require 'rails_helper'

RSpec.describe TimeRegister, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:clock_in) }
  end

  describe 'custom validations' do
    let(:user) { create(:user) }

    describe '#user_cannot_have_multiple_open_registers' do
      context 'when user has no existing open registers' do
        it 'allows creating an open time register' do
          time_register = build(:time_register, :open, user: user)
          
          expect(time_register).to be_valid
        end
      end

      context 'when user already has an open register' do
        before do
          create(:time_register, :open, user: user)
        end

        it 'does not allow creating another open register' do
          time_register = build(:time_register, :open, user: user)
          
          expect(time_register).to_not be_valid
          expect(time_register.errors[:base]).to include('User already has an open time register')
        end
      end

      context 'when creating a closed register' do
        before do
          create(:time_register, :open, user: user)
        end

        it 'allows creating a closed register even with existing open register' do
          time_register = build(:time_register, :closed, user: user)
          
          expect(time_register).to be_valid
        end
      end

      context 'when updating an existing open register' do
        let(:existing_register) { create(:time_register, :open, user: user) }

        it 'allows updating the same register without validation error' do
          existing_register.clock_in = 1.hour.ago
          
          expect(existing_register).to be_valid
        end
      end

      context 'when multiple users have open registers' do
        let(:another_user) { create(:user) }

        before do
          create(:time_register, :open, user: user)
          create(:time_register, :open, user: another_user)
        end

        it 'allows each user to have their own open register' do
          expect(user.time_registers.where(clock_out: nil)).to exist
          expect(another_user.time_registers.where(clock_out: nil)).to exist
        end
      end
    end

    describe '#clock_out_must_be_after_clock_in' do
      context 'when clock_out is after clock_in' do
        it 'is valid' do
          time_register = build(:time_register, clock_in: 2.hours.ago, clock_out: 1.hour.ago)
          
          expect(time_register).to be_valid
        end
      end

      context 'when clock_out is before clock_in' do
        it 'is invalid' do
          time_register = build(:time_register, clock_in: 1.hour.ago, clock_out: 2.hours.ago)
          
          expect(time_register).to_not be_valid
          expect(time_register.errors[:clock_out]).to include('must be after clock in time')
        end
      end

      context 'when clock_out equals clock_in' do
        let(:time) { 1.hour.ago }
        
        it 'is invalid' do
          time_register = build(:time_register, clock_in: time, clock_out: time)
          
          expect(time_register).to_not be_valid
          expect(time_register.errors[:clock_out]).to include('must be after clock in time')
        end
      end

      context 'when clock_out is nil (open register)' do
        it 'does not validate clock_out timing' do
          time_register = build(:time_register, :open)
          
          expect(time_register).to be_valid
        end
      end

      context 'when clock_in is nil' do
        it 'does not validate clock_out timing' do
          time_register = build(:time_register, clock_in: nil, clock_out: 1.hour.ago)
          
          # Should be invalid due to clock_in presence validation, not the custom validation
          expect(time_register).to_not be_valid
          expect(time_register.errors[:clock_out]).to_not include('must be after clock in time')
        end
      end
    end
  end

  describe 'complex scenarios' do
    let(:user) { create(:user) }

    it 'allows creating multiple closed registers for the same user' do
      create(:time_register, :closed, user: user)
      second_register = build(:time_register, :closed, user: user)
      
      expect(second_register).to be_valid
    end

    it 'prevents creating second open register even with different times' do
      create(:time_register, :open, user: user, clock_in: 2.hours.ago)
      second_register = build(:time_register, :open, user: user, clock_in: 1.hour.ago)
      
      expect(second_register).to_not be_valid
      expect(second_register.errors[:base]).to include('User already has an open time register')
    end

    it 'allows reopening after closing a register' do
      register = create(:time_register, :open, user: user)
      register.update!(clock_out: 1.hour.ago)
      
      new_register = build(:time_register, :open, user: user)
      expect(new_register).to be_valid
    end
  end
end