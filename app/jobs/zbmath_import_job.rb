class ZbmathImportJob < ApplicationJob
  queue_as :levriero

  def perform(item)
    Zbmath.parse_zbmath_record(item)
  end
end
