class ResolutionUpdateParseJob < ActiveJob::Base
  queue_as :levriero

  def perform(item, options={})
    logger = Logger.new(STDOUT)
    response = ResolutionUpdate.get_data(item, options)
    unless response.blank?
      data = ResolutionUpdate.parse_data(response, options)
      message  = data.respond_to?("each") ? "[Resolution Report Parsing] Successfully parsed Report #{item}"  : "[Resolution Report Parsing] Error parsing Report #{item}"
      logger.info message
      
      options.merge(
        report_meta:{
          report_id: item, 
          created_by: response.body.dig("data","report","report-header","created-by"), 
          reporting_period:response.body.dig("data","report","report-header","reporting-period")})
      ResolutionUpdate.push_data(data, options)
    end
  end
end