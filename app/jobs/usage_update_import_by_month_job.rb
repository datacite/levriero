class UsageUpdateImportByMonthJob < ActiveJob::Base
  queue_as :levriero_usage

  def perform(options={})
    UsageUpdate.import(options)
  end
end