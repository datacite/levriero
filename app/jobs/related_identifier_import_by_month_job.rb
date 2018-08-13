class RelatedIdentifierImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    RelatedIdentifier.import(options)
  end
end