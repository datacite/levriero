class CrossrefImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    Crossref.import(options)
  end
end