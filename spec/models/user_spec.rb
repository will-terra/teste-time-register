# spec/models/user_spec.rb

require 'rails_helper'

RSpec.describe User, type: :model do
  # Tests model associations
  describe 'associations' do
    # Verifies that User has many TimeRegisters with dependent destroy
    it { should have_many(:time_registers).dependent(:destroy) }
  end

  # Tests model validations
  describe 'validations' do
    subject { build(:user) }

    # Tests that name is required
    it { should validate_presence_of(:name) }
    # Tests that email is required
    it { should validate_presence_of(:email) }
    # Tests that email must be unique
    it { should validate_uniqueness_of(:email) }
    # Tests valid email formats
    it { should allow_value('user@example.com').for(:email) }
    it { should allow_value('test.user+tag@domain.co.uk').for(:email) }
    # Tests invalid email formats
    it { should_not allow_value('invalid-email').for(:email) }
    it { should_not allow_value('user@').for(:email) }
    it { should_not allow_value('@domain.com').for(:email) }
  end

  # Tests the method that checks if user has an open time register
  describe '#has_open_time_register?' do
    let(:user) { create(:user) }

    context 'when user has no time registers' do
      # Verifies that it returns false when no registers exist
      it 'returns false' do
        expect(user.has_open_time_register?).to be false
      end
    end

    context 'when user has only closed time registers' do
      before do
        create(:time_register, :closed, user: user)
        create(:time_register, :closed, user: user)
      end

      # Verifies that it returns false when all registers are closed
      it 'returns false' do
        expect(user.has_open_time_register?).to be false
      end
    end

    context 'when user has an open time register' do
      before do
        create(:time_register, :open, user: user)
      end

      # Verifies that it returns true when an open register exists
      it 'returns true' do
        expect(user.has_open_time_register?).to be true
      end
    end

    context 'when user has both open and closed time registers' do
      before do
        create(:time_register, :closed, user: user)
        create(:time_register, :open, user: user)
        create(:time_register, :closed, user: user)
      end

      # Verifies that it returns true when at least one open register exists
      it 'returns true' do
        expect(user.has_open_time_register?).to be true
      end
    end
  end

  # Tests dependent destroy behavior
  describe 'dependent destroy' do
    let(:user) { create(:user, :with_time_registers) }

    # Verifies that destroying user also destroys associated time registers
    it 'destroys associated time registers when user is destroyed' do
      time_register_ids = user.time_registers.pluck(:id)

      expect { user.destroy! }.to change { TimeRegister.count }.by(-3)

      time_register_ids.each do |id|
        expect(TimeRegister.find_by(id: id)).to be_nil
      end
    end
  end
end
