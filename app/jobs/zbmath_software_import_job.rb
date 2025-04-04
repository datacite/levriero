class ZbmathSoftwareImportJob < ApplicationJob
  queue_as :levriero

  def perform(item, options = {})
    ZbmathSoftware.process_zbmath_record(item)
  end
end
