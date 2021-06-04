class RelatedUrlImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    RelatedUrl.push_item(item)
  end
end
