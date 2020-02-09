class CrossrefRelatedImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    CrossrefRelated.push_item(item)
  end
end
