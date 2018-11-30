class ReportImportJob < ActiveJob::Base
  queue_as :levriero

  ICON_URL = "https://raw.githubusercontent.com/datacite/toccatore/master/lib/toccatore/images/toccatore.png"


  def perform(item, options={})
    logger = Logger.new(STDOUT)
    response = UsageUpdate.get_data(item, options)
    if response.status != 200
      logger.info "[Usage Report Parsing] Report #{item} not found"
      return {}
    else
      report = Report.new(response, options)
      text = "[Usage Report] Started to parse #{item}."
      logger.info text
      case report.get_type
        when "normal" then Report.parse_normal_report report
        when "compressed" then Report.parse_multi_subset_report report
      end
    end
  end
end
