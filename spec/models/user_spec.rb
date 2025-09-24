# spec/models/user_spec.rb

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:time_registers).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:user) }
    
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should allow_value('user@example.com').for(:email) }
    it { should allow_value('test.user+tag@domain.co.uk').for(:email) }
    it { should_not allow_value('invalid-email').for(:email) }
    it { should_not allow_value('user@').for(:email) }
    it { should_not allow_value('@domain.com').for(:email) }
  end

  describe '#has_open_time_register?' do
    let(:user) { create(:user) }

    context 'when user has no time registers' do
      it 'returns false' do
        expect(user.has_open_time_register?).to be false
      end
    end

    context 'when user has only closed time registers' do
      before do
        create(:time_register, :closed, user: user)
        create(:time_register, :closed, user: user)
      end

      it 'returns false' do
        expect(user.has_open_time_register?).to be false
      end
    end

    context 'when user has an open time register' do
      before do
        create(:time_register, :open, user: user)
      end

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

      it 'returns true' do
        expect(user.has_open_time_register?).to be true
      end
    end
  end

  describe 'dependent destroy' do
    let(:user) { create(:user, :with_time_registers) }

    it 'destroys associated time registers when user is destroyed' do
      time_register_ids = user.time_registers.pluck(:id)
      
      expect { user.destroy! }.to change { TimeRegister.count }.by(-3)
      
      time_register_ids.each do |id|
        expect(TimeRegister.find_by(id: id)).to be_nil
      end
    end
  end
end