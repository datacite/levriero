class CrossrefImportImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    CrossrefImport.push_item(item)
  end
end
