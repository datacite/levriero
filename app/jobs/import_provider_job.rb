class ImportProviderJob < ActiveJob::Base
  queue_as :levriero

  def perform(list)
    Provider.import_list(list)
  end
end
