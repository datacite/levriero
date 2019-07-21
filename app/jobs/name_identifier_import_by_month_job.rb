class NameIdentifierImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    NameIdentifier.import(options)
  end
end
