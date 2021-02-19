class RelatedIgsnImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    RelatedIgsn.push_item(item)
  end
end
