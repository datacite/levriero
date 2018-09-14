class UsageUpdateImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    UsageUpdate.push_item(item)
  end
end