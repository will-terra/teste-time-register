# spec/factories/time_registers.rb

FactoryBot.define do
  factory :time_register do
    association :user
    clock_in { Faker::Time.backward(days: 1, period: :morning) }
    clock_out { clock_in + 8.hours }

    trait :open do
      clock_out { nil }
    end

    trait :closed do
      clock_out { clock_in + rand(4..10).hours }
    end

    trait :invalid_times do
      clock_in { 2.hours.from_now }
      clock_out { 1.hour.from_now }
    end
  end
end