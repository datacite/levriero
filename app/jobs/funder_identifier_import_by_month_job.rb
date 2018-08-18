class FunderIdentifierImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    FunderIdentifier.import(options)
  end
end