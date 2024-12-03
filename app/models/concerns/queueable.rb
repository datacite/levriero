module Queueable
  extend ActiveSupport::Concern

  require "aws-sdk-sqs"

  class_methods do
    def send_event_import_message(data)
      if Rails.env.development?
        send_message_development(data, shoryuken_class: "EventImportWorker", queue_name: "events")
      else
        send_message(data, shoryuken_class: "EventImportWorker", queue_name: "events")
      end
    end

    private

    def send_message(body, options = {})
      queue_name_prefix = ENV["SQS_PREFIX"].present? ? ENV["SQS_PREFIX"] : Rails.env
      queue_url = sqs.get_queue_url(queue_name: "#{queue_name_prefix}_#{options[:queue_name]}").queue_url

      options = {
        queue_url: queue_url,
        message_attributes: {
          "shoryuken_class" => {
            string_value: options[:shoryuken_class],
            data_type: "String"
          },
        },
        message_body: body.to_json,
      }

      sqs = get_sqs_client

      sqs.send_message(options)
    end

    def get_sqs_client
      if Rails.env.development?
        Aws::SQS::Client.new(endpoint: "http://localhost:4566")
      else
        Aws::SQS::Client.new
      end
    end
  end
end
