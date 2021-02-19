class RelatedIgsnImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    RelatedIgsn.import(options)
  end
end
