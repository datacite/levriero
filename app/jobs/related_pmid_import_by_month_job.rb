class RelatedPmidImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    RelatedPmid.import(options)
  end
end
