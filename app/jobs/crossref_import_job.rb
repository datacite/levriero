class CrossrefImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    Crossref.push_item(item)
  end
end
