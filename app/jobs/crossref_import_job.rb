class CrossrefImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    Crossref.push_item(item)
  end
end