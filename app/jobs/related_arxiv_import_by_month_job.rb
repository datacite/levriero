class RelatedArxivImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    RelatedArxiv.import(options)
  end
end
