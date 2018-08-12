class EventImportWorker
  include Shoryuken::Worker

  shoryuken_options queue: ->{ "#{ENV['RAILS_ENV']}_event" }

  def perform(data)
    klass = Kernel.const_get(data.fetch("type").chomp('s').capitalize)
    klass.import_record(data)
  end
end
