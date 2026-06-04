module Queueable
  extend ActiveSupport::Concern

  require "aws-sdk-sqs"

  class_methods do
    def send_event_import_message(data)
      send_message(data, shoryuken_class: "EventImportWorker", queue_name: "events")
    end

    private

    def send_message(body, options = {})
      sqs = get_sqs_client
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

      sqs.send_message(options)
    end

    def get_sqs_client()
      if Rails.env.development?
        Aws::SQS::Client.new(endpoint: ENV["AWS_ENDPOINT"])
      else
        Aws::SQS::Client.new
      end
    end
  end
end
