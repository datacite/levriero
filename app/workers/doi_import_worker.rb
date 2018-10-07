class DoiImportWorker
  include Shoryuken::Worker

  shoryuken_options queue: ->{ "#{ENV['RAILS_ENV']}_doi" }, auto_delete: true

  def perform(sqs_msg, data)
    Doi.parse_record(data)
  end
end
