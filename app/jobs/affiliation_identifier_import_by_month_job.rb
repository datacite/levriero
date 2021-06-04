class AffiliationIdentifierImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    AffiliationIdentifier.import(options)
  end
end
