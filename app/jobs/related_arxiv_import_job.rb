class RelatedArxivImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    RelatedArxiv.push_item(item)
  end
end
