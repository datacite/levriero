module Queueable
  extend ActiveSupport::Concern

  require "aws-sdk-sqs"

  included do
    def send_event_import_message(data)
      send_message(data, shoryuken_class: "EventImportWorker", queue_name: "events")
    end
  end

  private

  def send_message(body, options = {})
    sqs = Aws::SQS::Client.new
    queue_name_prefix = ENV["SQS_PREFIX"].present? ? ENV["SQS_PREFIX"] : Rails.env
    queue_url =
      sqs.get_queue_url(queue_name: "#{queue_name_prefix}_#{options[:queue_name]}").queue_url
    options[:shoryuken_class] ||= "DoiImportWorker"

    options = {
      queue_url: queue_url,
      message_attributes: {
        "shoryuken_class" => {
          string_value: options[:shoryuken_class], data_type: "String"
        },
      },
      message_body: body.to_json,
    }

    sqs.send_message(options)
  end
end
