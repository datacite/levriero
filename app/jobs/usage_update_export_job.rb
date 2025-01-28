class UsageUpdateExportJob < ApplicationJob
  queue_as :levriero_usage

  def perform(item, options = {})
    UsageUpdate.push_item(item, options)
  end
end
