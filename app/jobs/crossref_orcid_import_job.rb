class CrossrefOrcidImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    CrossrefOrcid.push_item(item)
  end
end
