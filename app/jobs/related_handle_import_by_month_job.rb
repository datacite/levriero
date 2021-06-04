class RelatedHandleImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    RelatedHandle.import(options)
  end
end
