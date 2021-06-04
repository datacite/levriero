class NameIdentifierImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    NameIdentifier.import(options)
  end
end
