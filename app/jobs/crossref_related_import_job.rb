class CrossrefRelatedImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    CrossrefRelated.push_item(item)
  end
end
