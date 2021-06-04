class RelatedIgsnImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    RelatedIgsn.import(options)
  end
end
