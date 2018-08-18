class FunderIdentifierImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    FunderIdentifier.push_item(item)
  end
end