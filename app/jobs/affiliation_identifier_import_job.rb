class AffiliationIdentifierImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    AffiliationIdentifier.push_item(item)
  end
end