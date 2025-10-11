# spec/factories/time_registers.rb

FactoryBot.define do
  # Factory for creating time register test data
  factory :time_register do
    association :user  # Links the time register to a user
    clock_in { Faker::Time.backward(days: 1, period: :morning) }  # Random past morning time for clock in
    clock_out { clock_in + 8.hours }  # Sets clock out 8 hours after clock in

    # Trait for open time registers (no clock out time)
    trait :open do
      clock_out { nil }
    end

    # Trait for closed time registers with random work duration (4-10 hours)
    trait :closed do
      clock_out { clock_in + rand(4..10).hours }
    end

    # Trait for invalid time registers where clock out is before clock in
    trait :invalid_times do
      clock_in { 2.hours.from_now }
      clock_out { 1.hour.from_now }
    end
  end
end
