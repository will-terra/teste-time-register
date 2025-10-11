# spec/support/shoulda_matchers.rb

# Configuration for Shoulda Matchers gem
# Shoulda Matchers provides RSpec and Minitest matchers for testing Rails applications
# This configuration integrates Shoulda Matchers with RSpec and Rails
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
