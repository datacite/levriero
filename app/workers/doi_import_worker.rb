class DoiImportWorker
  include Shoryuken::Worker

  shoryuken_options queue: ->{ "#{ENV['RAILS_ENV']}_doi" }

  def perform(data)
    Doi.parse_record(data)
  end
end
