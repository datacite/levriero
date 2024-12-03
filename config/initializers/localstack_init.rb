require "aws-sdk-sqs"

# This initialization file will setup all of the necessary LocalStack resources.

Rails.logger.info("the environment is #{Rails.env}")
if Rails.env.development?
  Aws.config.update({
    region: "us-east-1",
    credentials: Aws::Credentials.new("test", "test")
  })

  sqs_client = Aws::SQS::Client.new(endpoint: "http://localstack:4566")
  response = sqs_client.create_queue(queue_name: "development_events")

  puts "Events Queue URL: #{response.queue_url}"
end
