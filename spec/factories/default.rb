require 'faker'

FactoryBot.define do
  factory :client do
    association :provider, factory: :provider, strategy: :build

    contact_email { Faker::Internet.email }
    contact_name { Faker::Name.name }
    sequence(:symbol) { |n| provider.symbol + ".TEST#{n}" }
    name { Faker::GameOfThrones.city  }
    role_name "ROLE_DATACENTRE"
    provider_id  { provider.symbol.downcase }
    created { Faker::Time.between(DateTime.now - 2, DateTime.now) }

  end

  factory :provider do
    contact_email { Faker::Internet.email }
    contact_name { Faker::Name.name }
    sequence(:symbol) { |n| "TEST#{n}" }
    name { Faker::GameOfThrones.city }
    country_code { Faker::Address.country_code }
    created { Faker::Time.between(DateTime.now - 2, DateTime.now) }

    # initialize_with { Provider.where(symbol: symbol).first_or_initialize }
  end
end
