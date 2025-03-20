class ZbmathImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    Zbmath.import(options)
  end
end
