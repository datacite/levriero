class CrossrefImportImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    CrossrefImport.import(options)
  end
end
