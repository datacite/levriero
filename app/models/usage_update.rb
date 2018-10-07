class UsageUpdate < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"
  LOGGER = Logger.new(STDOUT)


  def self.import(_options={})
    usage_update = UsageUpdate.new
    usage_update.queue_jobs 
  end

  def source_id
    "usage_update"
  end


  def process_data options={} 
    messages = get_query_url options
    messages.each do |message|
      body = JSON.parse(message.body)
      report_id = body["report_id"]
      UsageUpdateParseJob.perform_later(report_id, options)
      delete_message message
    end if messages.respond_to?("each")
    messages.length
  end

  def get_query_url _options={}
    queue_url = sqs.get_queue_url(queue_name: "#{Rails.env}_usage" ).queue_url
    resp = sqs.receive_message(queue_url: queue_url, max_number_of_messages: 5, wait_time_seconds: 1)
    resp.messages
  end

  def self.get_data report_id, _options={}
    return OpenStruct.new(body: { "errors" => "No Report given given"}) if report_id.blank?
    host = URI.parse(report_id).host.downcase
    report = Maremma.get(report_id, timeout: 120, host: host)
    report
  end

  def sqs
    sqs = Aws::SQS::Client.new(region: ENV["AWS_REGION"])
    sqs
  end


  def get_total(options={})
    queue_url = sqs.get_queue_url(queue_name: "#{Rails.env}_usage" ).queue_url
    req = sqs.get_queue_attributes(
      {
        queue_url: queue_url, attribute_names: 
          [
            'ApproximateNumberOfMessages', 
            'ApproximateNumberOfMessagesNotVisible'
          ]
      }
    )

    msgs_available = req.attributes['ApproximateNumberOfMessages']
    msgs_available.to_i
  end

  def queue_jobs(options={})

    total = get_total(options)
    
    if total < 1
      text = "No works found in the Usage Reports Queue."
    end

    num_messages = total
    while num_messages > 0 
        queued = process_data(options)
        num_messages -= queued
        puts num_messages
        puts queued
    end
    text = "#{queued} reports queued out of #{total} for Usage Reports Queue"

    LOGGER.info text
    # send slack notification
    if queued == 0
      options[:level] = "warning"
    else
      options[:level] = "good"
    end
    options[:title] = "Report for #{source_id}"
    send_notification_to_slack(text, options) if options[:slack_webhook_url].present?
    queued
  end

  def self.parse_data report, options={}

    return report.body.fetch("errors") if report.body.fetch("errors", nil).present?
    return [{ "errors" => { "title" => "The report is blank" }}] if report.body.blank?

    items = report.body.dig("data","report","report-datasets")
    header = report.body.dig("data","report","report-header")
    report_id = report.url

    Array.wrap(items).reduce([]) do |x, item|
      data = { 
        doi: item.dig("dataset-id").first.dig("value"), 
        id: normalize_doi(item.dig("dataset-id").first.dig("value")),
        created: header.fetch("created"), 
        report_id: report.url,
        created_at: header.fetch("created")
      }
      instances = item.dig("performance", 0, "instance")

      return x += [OpenStruct.new(body: { "errors" => "There are too many instances in #{data[:doi]} for report #{report_id}. There can only be 4" })] if instances.size > 8
   
      x += Array.wrap(instances).reduce([]) do |ssum, instance|
        data[:count] = instance.dig("count")
        event_type = "#{instance.dig("metric-type")}-#{instance.dig("access-method")}"
        ssum << format_event(event_type, data, options)
        ssum
      end
    end    
  end

  def self.format_event type, data, options={}
    fail "Not type given. Report #{data[:report_id]} not proccessed" if type.blank?
    fail "Access token missing." if ENV['DATACITE_USAGE_SOURCE_TOKEN'].blank?
    fail "Report_id is missing" if data[:report_id].blank?
    
    { "message-action" => "create",
      "subj-id" => data[:report_id],
      "subj"=> {
        "id"=> data[:report_id],
        "issued"=> data[:created]
      },
      "total"=> data[:count],
      "obj-id" => data[:id],
      "relation-type-id" => type,
      "source-id" => "datacite-usage",
      "source-token" =>ENV['DATACITE_USAGE_SOURCE_TOKEN'],
      "occurred-at" => data[:created_at],
      "license" => LICENSE 
    }
  end

  # method returns number of errors
  def self.push_data items, options={}
    if items.empty?
      LOGGER.info  "No works found in the Queue."
    else
      Array.wrap(items).map do |item|
        UsageUpdateImportJob.perform_later(item.to_json, options)
      end
    end
  end

  def self.push_item item, options={}
    item = JSON.parse(item)

    if item["subj-id"].blank?
      return LOGGER.info OpenStruct.new(body: { "errors" => [{ "title" => "There is no Subject" }] })
    elsif ENV['LAGOTTINO_TOKEN'].blank?
      return LOGGER.info OpenStruct.new(body: { "errors" => [{ "title" => "Access token missing." }] })
    elsif item["errors"].present?
      return LOGGER.info OpenStruct.new(body: { "errors" => [{ "title" => "#{item["errors"]["title"]}" }] }) 
    end

    obj = cached_datacite_response(item["obj-id"])
    subj = options[:report_meta]
    push_url = ENV['LAGOTTINO_URL']  + "/events"
    data = { 
      "data" => {
        "type" => "events",
        "attributes" => {
          "message-action" => item["message-action"],
          "subj-id" => item["subj-id"],
          "obj-id" => item["obj-id"],
          "relation-type-id" => item["relation-type-id"].to_s.dasherize,
          "source-id" => item["source-id"].to_s.dasherize,
          "source-token" => item["source-token"],
          "occurred-at" => item["occurred-at"],
          "timestamp" => item["timestamp"],
          "license" => item["license"],
          "subj" => subj,
          "obj" => obj } }}
  
    response = Maremma.post(push_url, data: data.to_json,
                                      bearer: ENV['LAGOTTINO_TOKEN'],
                                      content_type: 'application/vnd.api+json')               
  end
end

