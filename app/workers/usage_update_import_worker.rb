class UsageUpdateImportWorker
  include Shoryuken::Worker

  shoryuken_options queue: ->{ "#{ENV['RAILS_ENV']}_usage" }, auto_delete: true

  def perform(sqs_msg, data)
    UsageUpdate.grab_record(sqs_msg: sqs_msg, data: JSON.parse(data))
  end
end
