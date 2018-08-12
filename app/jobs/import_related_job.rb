class ImportRelatedJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    Doi.
  end
end