class AffiliationIdentifierImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    AffiliationIdentifier.push_item(item)
  end
end
