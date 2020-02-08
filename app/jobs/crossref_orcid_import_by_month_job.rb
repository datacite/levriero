class CrossrefOrcidImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    CrossrefOrcid.import(options)
  end
end
