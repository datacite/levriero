class CrossrefRelatedImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    CrossrefRelated.import(options)
  end
end
