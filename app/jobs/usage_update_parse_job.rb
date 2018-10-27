class UsageUpdateParseJob < ActiveJob::Base
  queue_as :levriero

  def perform(item, options={})
    logger = Logger.new(STDOUT)
    response = UsageUpdate.get_data(item, options)
    if response.status != 200
      logger.info "Report #{item} not found"
      return {}
    else
      data = UsageUpdate.parse_data(response, options)
      message  = data.respond_to?("each") ? "[Usage Report Parsing] Successfully parsed Report #{item} with #{data.length} instances"  : "[Usage Report Parsing] Error parsing Report #{item}"
      logger.info message
      
      options.merge(
        report_meta:{
          report_id: item, 
          created_by: response.body.dig("data","report","report-header","created-by"), 
          reporting_period:response.body.dig("data","report","report-header","reporting-period")})
      UsageUpdate.push_data(data, options)
    end
  end
end
