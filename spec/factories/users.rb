# spec/factories/users.rb

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    
    trait :with_time_registers do
      after(:create) do |user|
        create_list(:time_register, 3, user: user)
      end
    end

    trait :with_open_time_register do
      after(:create) do |user|
        create(:time_register, :open, user: user)
      end
    end
  end
end