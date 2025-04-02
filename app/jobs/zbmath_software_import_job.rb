class ZbmathSoftwareImportJob < ApplicationJob
  queue_as :levriero

  def perform(item, options = {})
    ZbmathSoftware.parse_zbmath_record(item, options)
  end
end
