class EventImportWorker
  include Shoryuken::Worker

  shoryuken_options queue: -> { "#{ENV['RAILS_ENV']}_events" }, auto_delete: true

  def perform(sqs_msg=nil, data=nil)
    Event.process_message(sqs_msg, data)
  end
end
