class OrcidClaimImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    OrcidClaim.push_item(item)
  end
end