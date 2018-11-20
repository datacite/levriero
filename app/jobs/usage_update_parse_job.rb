class UsageUpdateParseJob < ActiveJob::Base
  queue_as :levriero

  def perform(item, options={})
    logger = Logger.new(STDOUT)
    response = UsageUpdate.get_data(item, options)
    if response.status != 200
      logger.info "[Usage Report Parsing] Report #{item} not found"
      return {}
    else
      # data = UsageUpdate.parse_data(response, options)
      data = Report.new(response, options).parse_data
      send_message(data,item,options)
      # message  = data.respond_to?("each") ? "[Usage Report Parsing] Successfully parsed Report #{item} with #{data.length} instances"  : "[Usage Report Parsing] Error parsing Report #{item}"
      
      options.merge(
        report_meta:{
          report_id: item, 
          created_by: response.body.dig("data","report","report-header","created-by"), 
          reporting_period:response.body.dig("data","report","report-header","reporting-period")})
      UsageUpdate.push_data(data, options) unless Rails.env.test?
    end
  end

  def send_message data, item, options={}
    logger = Logger.new(STDOUT)
    errors = data.select {|hsh| hsh.fetch("errors",nil) }
    if data.length == 0
      options[:level] = "warning"
      text = "[Usage Report Parsing] Error parsing Report #{item}. Report is empty"
    elsif !errors.empty?
      options[:level] = "warning"
      text = "[Usage Report Parsing] #{errors.length} Errors in report #{item}. #{errors}"
    elsif data.respond_to?("each").nil? 
      options[:level] = "danger"
      text = "[Usage Report Parsing] Something went wrong with #{item}."
    else
      options[:level] = "good"
      text ="[Usage Report Parsing] Successfully parsed Report #{item} with #{data.length} instances"
    end

    logger.info text
    send_notification_to_slack(text, options) if options[:slack_webhook_url].present?
  end
end
