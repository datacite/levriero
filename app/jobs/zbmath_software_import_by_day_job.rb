class ZbmathSoftwareImportByDayJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    ZbmathSoftware.import(options)
  end
end
