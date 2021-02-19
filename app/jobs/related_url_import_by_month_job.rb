class RelatedUrlImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    RelatedUrl.import(options)
  end
end
