require 'faker'

FactoryBot.define do
  factory :client do
    sequence(:provider_id) { |n| "test#{n}" }
    sequence(:id) { |n| provider_id + ".test#{n}" }
    symbol { id.upcase }
    contact_email { Faker::Internet.email }
    contact_name { Faker::Name.name }
    name { Faker::GameOfThrones.city  }
    created { Faker::Time.between(DateTime.now - 2, DateTime.now) }

    skip_create
    initialize_with { Client.create(attributes) }
  end

  factory :provider do
    sequence(:id) { |n| "test#{n}" }
    symbol { id.upcase }
    contact_email { Faker::Internet.email }
    contact_name { Faker::Name.name }
    name { Faker::GameOfThrones.city }
    country_code { Faker::Address.country_code }
    created { Faker::Time.between(DateTime.now - 2, DateTime.now) }

    skip_create
    initialize_with { Provider.create(attributes) }
  end
end
