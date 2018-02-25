class ElasticWorker
  include Shoryuken::Worker

  shoryuken_options queue: ->{ "#{ENV['RAILS_ENV']}_elastic" }

  def perform(data: nil, action: nil)
    if action == "delete"
      Rails.logger.info action
    elsif data.fetch("type", nil) == "clients"
      Client.import_record(data.fetch("attributes", {}))
    elsif data.fetch("type", nil) == "providers"
      Provider.import_record(data.fetch("attributes", {}))
    end
  end
end
