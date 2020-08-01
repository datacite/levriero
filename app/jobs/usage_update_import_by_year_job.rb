class UsageUpdateImportByYearJob < ActiveJob::Base
  queue_as :levriero_usage

  def perform(options={})
    UsageUpdate.import_reports(options)
  end
end