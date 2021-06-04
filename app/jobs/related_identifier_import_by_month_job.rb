class RelatedIdentifierImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    RelatedIdentifier.import(options)
  end
end
