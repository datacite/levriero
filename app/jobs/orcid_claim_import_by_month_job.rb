class OrcidClaimImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    OrcidClaim.import(options)
  end
end
