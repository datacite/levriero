class CrossrefFunderImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item)
    CrossrefFunder.push_item(item)
  end
end
