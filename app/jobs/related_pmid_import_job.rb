class RelatedPmidImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    RelatedPmid.push_item(item)
  end
end
