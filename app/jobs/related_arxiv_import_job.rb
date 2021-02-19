class RelatedArxivImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    RelatedArxiv.push_item(item)
  end
end