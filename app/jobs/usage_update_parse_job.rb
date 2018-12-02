class UsageUpdateParseJob < ActiveJob::Base
  queue_as :levriero


  ICON_URL = "https://raw.githubusercontent.com/datacite/toccatore/master/lib/toccatore/images/toccatore.png"


  def perform(dataset, options)

    # response = UsageUpdate.get_data(report_url, options)
    # report = Report.new(report_header, options)
    data = Report.translate_datasets dataset, options
    # data = Report.new(response, options).parse_data
    send_message(data,options[:url],{slack_webhook_url: ENV['SLACK_WEBHOOK_URL']})
    puts options[:header]
    options.merge(
      report_meta:{
        report_id: options[:header].dig("report-id"), 
        created_by: options[:header].dig("created-by"),
        reporting_period: options[:header].dig("reporting-period")})

    UsageUpdate.push_datasets(data, options) unless Rails.env.test?
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

  end
end
