class CrossrefOrcidImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    Rails.logger.info item.inspect
    CrossrefOrcid.push_item(item)
  end
end
