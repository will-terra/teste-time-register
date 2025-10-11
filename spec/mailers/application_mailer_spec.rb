# spec/mailers/application_mailer_spec.rb

require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  # Tests the ApplicationMailer base class configuration
  describe 'base configuration' do
    # Verifies that ApplicationMailer inherits from ActionMailer::Base
    it 'inherits from ActionMailer::Base' do
      expect(described_class.superclass).to eq(ActionMailer::Base)
    end

    # Verifies that the default from address is correctly set
    it 'has correct default from address' do
      expect(described_class.default[:from]).to eq('from@example.com')
    end
  end

  # Tests mailer configuration and behavior
  describe 'mailer behavior' do
    # Verifies that deliveries array is available for testing
    it 'has deliveries array for testing' do
      expect(ActionMailer::Base.deliveries).to be_an(Array)
    end

    # Verifies that delivery method is set to test in test environment
    it 'uses test delivery method in test environment' do
      expect(ActionMailer::Base.delivery_method).to eq(:test)
    end
  end
end