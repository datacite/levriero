class OrcidAffiliationImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    OrcidAffiliation.push_item(item)
  end
end
