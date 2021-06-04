class CrossrefImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    Crossref.import(options)
  end
end
