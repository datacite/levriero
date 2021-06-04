class CrossrefOrcidImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    CrossrefOrcid.push_item(item)
  end
end
