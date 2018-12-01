class UsageUpdateParseJob < ActiveJob::Base
  queue_as :levriero

  ICON_URL = "https://raw.githubusercontent.com/datacite/toccatore/master/lib/toccatore/images/toccatore.png"


  def perform(report_url, hsh, options={})
    response = UsageUpdate.get_data(report_url, options)
    report = Report.new(response, options)
    data = report.translate_datasets hsh
    # data = Report.new(response, options).parse_data
    send_message(data,report.report_id,{slack_webhook_url: ENV['SLACK_WEBHOOK_URL']})
    puts report.header
    options.merge(
      report_meta:{
        report_id: report.report_id, 
        created_by: report.header.dig("created-by"),
        reporting_period: report.header.dig("reporting-period")})

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

    if options[:slack_webhook_url].present?
      attachment = {
        title: options[:title] || "Report",
        text: text,
        color: options[:level] || "good"
      }
      notifier = Slack::Notifier.new options[:slack_webhook_url],
                                      username: "Event Data Agent",
                                      icon_url: ICON_URL
      notifier.post attachments: [attachment]
    end
  end
end
