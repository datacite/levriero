class RelatedHandleImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    RelatedHandle.push_item(item)
  end
end
