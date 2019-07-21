class OrcidAffiliationImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    OrcidAffiliation.push_item(item)
  end
end
