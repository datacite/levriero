class RelatedArxivImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    RelatedArxiv.import(options)
  end
end