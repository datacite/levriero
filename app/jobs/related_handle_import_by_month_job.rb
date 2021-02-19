class RelatedHandleImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    RelatedHandle.import(options)
  end
end
