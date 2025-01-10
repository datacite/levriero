class DoiImportWorker
  include Shoryuken::Worker

  shoryuken_options queue: -> { "#{ENV['RAILS_ENV']}_doi" }, auto_delete: true

  def perform(sqs_msg, data)
    Rails.logger.info("DOI Import Worker")
    Rails.logger.info(data)
    Rails.logger.info(JSON.parse(data))
    Doi.parse_record(sqs_msg: sqs_msg, data: JSON.parse(data))
  end
end
