require "faker"

FactoryBot.define do
  factory :doi, class: OpenStruct do
    doi { "10.14454/#{Faker::Internet.password(8)}".downcase }
    url { Faker::Internet.url }
    is_active { true }
    xml do
      "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9InllcyI/PjxyZXNvdXJjZSB4c2k6c2NoZW1hTG9jYXRpb249Imh0dHA6Ly9kYXRhY2l0ZS5vcmcvc2NoZW1hL2tlcm5lbC0zIGh0dHA6Ly9zY2hlbWEuZGF0YWNpdGUub3JnL21ldGEva2VybmVsLTMvbWV0YWRhdGEueHNkIiB4bWxucz0iaHR0cDovL2RhdGFjaXRlLm9yZy9zY2hlbWEva2VybmVsLTMiIHhtbG5zOnhzaT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS9YTUxTY2hlbWEtaW5zdGFuY2UiPjxpZGVudGlmaWVyIGlkZW50aWZpZXJUeXBlPSJET0kiPjEwLjUyNTYvZjEwMDByZXNlYXJjaC44NTcwLnI2NDIwPC9pZGVudGlmaWVyPjxjcmVhdG9ycz48Y3JlYXRvcj48Y3JlYXRvck5hbWU+ZCBzPC9jcmVhdG9yTmFtZT48L2NyZWF0b3I+PC9jcmVhdG9ycz48dGl0bGVzPjx0aXRsZT5SZWZlcmVlIHJlcG9ydC4gRm9yOiBSRVNFQVJDSC0zNDgyIFt2ZXJzaW9uIDU7IHJlZmVyZWVzOiAxIGFwcHJvdmVkLCAxIGFwcHJvdmVkIHdpdGggcmVzZXJ2YXRpb25zXTwvdGl0bGU+PC90aXRsZXM+PHB1Ymxpc2hlcj5GMTAwMCBSZXNlYXJjaCBMaW1pdGVkPC9wdWJsaXNoZXI+PHB1YmxpY2F0aW9uWWVhcj4yMDE3PC9wdWJsaWNhdGlvblllYXI+PHJlc291cmNlVHlwZSByZXNvdXJjZVR5cGVHZW5lcmFsPSJUZXh0Ii8+PC9yZXNvdXJjZT4="
    end
    aasm_state { "draft" }
    created_at { Faker::Time.between(DateTime.now - 2, DateTime.now) }
    updated_at { created_at }

    skip_create
    initialize_with { new(attributes) }
  end

  factory :event, class: OpenStruct do
    sequence(:uuid) { |n| "#{SecureRandom.uuid}-#{n}" }
    message_action { "create" }
    sequence(:obj_id) { |n| "#{Faker::Internet.url}#{n}" }
    sequence(:subj_id) { |n| "#{Faker::Internet.url}#{n}" }
    total { Faker::Number.number(digits: 3) }
    subj do
      {
        "id" => SecureRandom.uuid.to_s,
        "issued" => Faker::Time.between(from: DateTime.now - 2,
                                        to: DateTime.now),
      }
    end
    relation_type_id do
      ["total-dataset-investigations-regular",
       "total-dataset-investigations-machine", "unique-dataset-investigations-machine", "total-dataset-investigations-machine"].sample
    end
    source_id { "datacite-usage" }
    sequence(:source_token) { |n| "#{SecureRandom.uuid}-#{n}" }
    occurred_at do
      Faker::Time.between(from: DateTime.now - 2, to: DateTime.now)
    end
    license { "https://creativecommons.org/publicdomain/zero/1.0/" }
  end
end
