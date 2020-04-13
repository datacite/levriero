class CrossrefFunderImportByMonthJob < ActiveJob::Base
  queue_as :levriero

  def perform(options={})
    CrossrefFunder.import(options)
  end
end
