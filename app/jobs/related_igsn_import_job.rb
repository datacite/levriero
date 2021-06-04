class RelatedIgsnImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    RelatedIgsn.push_item(item)
  end
end
