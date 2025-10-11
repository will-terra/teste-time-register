# spec/factories/users.rb

FactoryBot.define do
  # Factory for creating user test data
  factory :user do
    name { Faker::Name.name }  # Generates a random name
    email { Faker::Internet.unique.email }  # Generates a unique email address

    # Trait that creates 3 associated time registers after user creation
    trait :with_time_registers do
      after(:create) do |user|
        create_list(:time_register, 3, user: user)
      end
    end

    # Trait that creates one open time register after user creation
    trait :with_open_time_register do
      after(:create) do |user|
        create(:time_register, :open, user: user)
      end
    end
  end
end
