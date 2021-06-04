class NameIdentifierImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    NameIdentifier.push_item(item)
  end
end
