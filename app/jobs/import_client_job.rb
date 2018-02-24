class ImportClientJob < ActiveJob::Base
  queue_as :levriero

  def perform(list)
    Client.import_list(list)
  end
end
