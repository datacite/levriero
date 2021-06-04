class CrossrefFunderImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    CrossrefFunder.import(options)
  end
end
