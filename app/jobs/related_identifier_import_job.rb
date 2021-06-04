class RelatedIdentifierImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    RelatedIdentifier.push_item(item)
  end
end
