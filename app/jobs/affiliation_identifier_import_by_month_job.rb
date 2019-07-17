class AffiliationIdentifierImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    AffiliationIdentifier.import(options)
  end
end