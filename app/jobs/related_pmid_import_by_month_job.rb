class RelatedPmidImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    RelatedPmid.import(options)
  end
end
