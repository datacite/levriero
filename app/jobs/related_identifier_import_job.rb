class RelatedIdentifierImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    RelatedIdentifier.push_item(item)
  end
end