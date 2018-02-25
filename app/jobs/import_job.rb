class ImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(data)
    klass = classify(data.fetch("type"))
    klass.import_record(data)
  end
end
