class UsageUpdateImportWorker
  include Shoryuken::Worker

  shoryuken_options queue: ->{ "#{ENV['RAILS_ENV']}_usage" }, auto_delete: true

  def perform(sqs_msg, data)
    UsageUpdate.parse_record(sqs_msg: sqs_msg, data: JSON.parse(data)) unless Rails.env.production?
  end
end
