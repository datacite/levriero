class UsageUpdate < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"
  LOGGER = Logger.new(STDOUT)

  USAGE_RELATIONS = [
    "total-dataset-investigations-regular",
    "total-dataset-investigations-machine",
    "total-dataset-requests-machine",
    "total-dataset-requests-regular",
    "unique-dataset-investigations-regular",
    "unique-dataset-investigations-machine",
    "unique-dataset-requests-machine",
    "unique-dataset-requests-regular"
  ]

  RESOLUTION_RELATIONS = [
    "total-resolutions-regular",
    "total-resolutions-machine",
    "unique-resolutions-machine",
    "unique-resolutions-regular"
  ]

  def self.import(_options={})
    usage_update = UsageUpdate.new
    usage_update.queue_jobs 
  end

  def self.get_data report_id, _options={}
    return OpenStruct.new(body: { "errors" => "No Report given given"}) if report_id.blank?
    host = URI.parse(report_id).host.downcase
    report = Maremma.get(report_id, timeout: 120, host: host)
    report
  end

  def self.parse_record sqs_msg: nil, data: nil
    report_id = data.fetch("report_id", "")
    UsageUpdateParseJob.perform_later(report_id)
  end

  def sqs
    sqs = Aws::SQS::Client.new(region: ENV["AWS_REGION"])
    sqs
  end


  def self.parse_data report, options={}

    return report.body.fetch("errors") if report.body.fetch("errors", nil).present?
    return [{ "errors" => { "title" => "The report is blank" }}] if report.body.blank?

    data = report.body.fetch("data", {})

    items = data.dig("report","report-datasets")
    header = data.dig("report","report-header")
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
    fail "Report_id is missing" if data[:report_id].blank?

    if USAGE_RELATIONS.include?(type.downcase)
      source_id = "datacite-usage"
      source_token = ENV['DATACITE_USAGE_SOURCE_TOKEN']
    elsif RESOLUTION_RELATIONS.include?(type.downcase)
      source_id = "datacite-resolution"
      source_token = ENV['DATACITE_RESOLUTION_SOURCE_TOKEN']
    end
    { "message-action" => "create",
      "subj-id" => data[:report_id],
      "subj"=> {
        "id"=> data[:report_id],
        "issued"=> data[:created]
      },
      "total"=> data[:count],
      "obj-id" => data[:id],
      "relation-type-id" => type,
      "source-id" => source_id,
      "source-token" => source_token,
      "occurred-at" => data[:created_at],
      "license" => LICENSE 
    }
  end

  def self.push_data items, options={}
    if items.empty?
      LOGGER.info  "No works found in the Queue."
    else
      Array.wrap(items).map do |item|
        UsageUpdateExportJob.perform_later(item.to_json, options)
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

    data = wrap_event item, options
    push_url = ENV['LAGOTTINO_URL']  + "/events"

  
    response = Maremma.post(push_url, data: data.to_json,
                                      bearer: ENV['LAGOTTINO_TOKEN'],
                                      content_type: 'application/vnd.api+json')
  end


  def self.wrap_event item, options={}
    obj = cached_datacite_response(item["obj-id"])
    subj = options[:report_meta]
    { 
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
  end
end

