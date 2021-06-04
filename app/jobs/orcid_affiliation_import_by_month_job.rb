class OrcidAffiliationImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    OrcidAffiliation.import(options)
  end
end
