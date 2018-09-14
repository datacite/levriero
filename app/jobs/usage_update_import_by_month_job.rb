class UsageUpdateImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    UsageUpdate.import(options)
  end
end