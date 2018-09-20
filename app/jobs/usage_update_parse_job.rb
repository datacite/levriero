class UsageUpdateParseJob < ActiveJob::Base
  queue_as :levriero

  def perform(item, options={})
    logger = Logger.new(STDOUT)
    response = UsageUpdate.get_data(item, options)
    data = UsageUpdate.parse_data(response, options)
    message  = data.respond_to?("each") ? "[Usage Report Parsing] Successfully parsed Report #{item}"  : "[Usage Report Parsing] Error parsing Report #{item}"
    logger.info message
    UsageUpdate.push_data(data, options)
  end
end