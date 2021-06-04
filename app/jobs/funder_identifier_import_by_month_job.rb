class FunderIdentifierImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    FunderIdentifier.import(options)
  end
end
