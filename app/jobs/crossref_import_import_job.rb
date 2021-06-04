class CrossrefImportImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    CrossrefImport.push_item(item)
  end
end
