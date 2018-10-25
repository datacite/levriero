class NameIdentifierImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    NameIdentifier.push_item(item)
  end
end