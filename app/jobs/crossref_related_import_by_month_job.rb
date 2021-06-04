class CrossrefRelatedImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    CrossrefRelated.import(options)
  end
end
