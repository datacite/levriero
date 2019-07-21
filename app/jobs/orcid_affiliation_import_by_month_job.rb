class OrcidAffiliationImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    OrcidAffiliation.import(options)
  end
end
