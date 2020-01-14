class UsageUpdateParseJob < ActiveJob::Base
  queue_as :levriero

  ICON_URL = "https://raw.githubusercontent.com/datacite/toccatore/master/lib/toccatore/images/toccatore.png".freeze

  def perform(dataset, options)
    # response = UsageUpdate.get_data(report_url, options)
    # report = Report.new(report_header, options)
    data = Report.translate_datasets dataset, options
    # data = Report.new(response, options).parse_data
    send_message(data, options[:url], slack_webhook_url: ENV["SLACK_WEBHOOK_URL"])
    options.merge(
      report_meta: {
        report_id: options[:header].dig("report-id"),
        created_by: options[:header].dig("created-by"),
        reporting_period: options[:header].dig("reporting-period"),
      },
    )

    UsageUpdate.push_datasets(data, options) unless Rails.env.test?
  end

  def send_message(data, item, _options = {})
    errors = data.select { |hsh| hsh.fetch("errors", nil) }
    if data.length.zero?
      # options[:level] = "warning"
      Rails.logger.error "[Usage Report Parsing] Error parsing Report #{item}. Report is empty"
    elsif !errors.empty?
      # options[:level] = "warning"
      Rails.logger.error "[Usage Report Parsing] #{errors.length} Errors in report #{item}. #{errors}"
    elsif data.respond_to?("each").nil?
      # options[:level] = "danger"
      Rails.logger.fatal "[Usage Report Parsing] Something went wrong with #{item}."
    else
      # options[:level] = "good"
      Rails.logger.info "[Usage Report Parsing] Successfully parsed Report #{item} with #{data.length} instances"
    end
  end
end
