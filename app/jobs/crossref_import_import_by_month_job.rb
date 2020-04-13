class CrossrefImportImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    CrossrefImport.import(options)
  end
end
