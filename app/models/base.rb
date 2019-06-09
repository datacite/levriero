require "bolognese"

class Base
  include Importable
  include Cacheable
  include ::Bolognese::MetadataUtils

  # icon for Slack messages
  ICON_URL = "https://raw.githubusercontent.com/datacite/toccatore/master/lib/toccatore/images/toccatore.png"

  def queue options={}
    logger = Logger.new(STDOUT)
    logger.info "Queue name has not been specified" unless ENV['ENVIRONMENT'].present?
    logger.info "AWS_REGION has not been specified" unless ENV['AWS_REGION'].present?
    region = ENV['AWS_REGION'] ||= 'eu-west-1'
    Aws::SQS::Client.new(region: region.to_s, stub_responses: false)
  end

  def get_message options={}
    sqs.receive_message(queue_url: queue_url, max_number_of_messages: 1, wait_time_seconds: 1)
  end

  def delete_message message
    logger = Logger.new(STDOUT)

    response = sqs.delete_message({
      queue_url: queue_url,
      receipt_handle: message[:receipt_handle]    
    })
    if response.successful?
      logger.info "Message #{message[:receipt_handle]} deleted"
    else
      logger.info "Could NOT delete Message #{message[:receipt_handle]}"
    end
  end

  def queue_url(options={})
    options[:queue_name] ||= "#{ENV['ENVIRONMENT']}_usage" 
    queue_name = options[:queue_name] 
    # puts "Using  #{sqs.get_queue_url(queue_name: queue_name).queue_url} queue"
    sqs.get_queue_url(queue_name: queue_name).queue_url
  end
  
  def get_query_url(options={})
    options[:number] ||= 1
    options[:size] ||= 1000
    updated = "updated:[#{options[:from_date]}T00:00:00Z TO #{options[:until_date]}T23:59:59Z]"

    # if options[:doi].present?
    #   query = "doi:#{options[:doi]}"
    # elsif options[:orcid].present?
    #   query = "nameIdentifiers.nameIdentifier\\:#{options[:orcid]}"
    # elsif options[:related_identifier].present?
    #   query = "relatedIdentifiers.relatedIdentifier\\:#{options[:related_identifier]}"
    # elsif options[:query].present?
    #   query = options[:query]
    # else
    #   query = query
    # end

    params = { 
      query: query + " AND " + updated,
      "page[number]" => options[:number],
      "page[size]" => options[:size] }

    url +  URI.encode_www_form(params)
  end

  def get_total(options={})
    query_url = get_query_url(options.merge(size: 0))
    result = Maremma.get(query_url, options)
    result.body.dig("meta", "total").to_i
  end

  def queue_jobs(options={})
    logger = Logger.new(STDOUT)

    options[:number] = options[:number].to_i || 1
    options[:size] = options[:size].presence || job_batch_size
    options[:from_date] = options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
    options[:until_date] = options[:until_date].presence || Time.now.to_date.iso8601
    options[:content_type] = 'json'

    total = get_total(options)

    if total > 0
      # walk through paginated results
      total_pages = (total.to_f / job_batch_size).ceil
      error_total = 0

      (0...total_pages).each do |page|
        options[:number] = page
        options[:total] = total
        process_data(options)
      end
      text = "[Event Data] Queued #{source_id} import for #{total} DOIs updated #{options[:from_date]} - #{options[:until_date]}."
    else
      text = "[Event Data] No DOIs updated #{options[:from_date]} - #{options[:until_date]} for #{source_id}."
    end

    logger.info text

    # send slack notification
    if total == 0
      options[:level] = "warning"
    elsif error_total > 0
      options[:level] = "danger"
    else
      options[:level] = "good"
    end
    options[:title] = "Report for #{source_id}"
    send_notification_to_slack(text, options) if options[:slack_webhook_url].present?

    # return number of dois queued
    total
  end

  def process_data(options = {})
    data = get_data(options.merge(timeout: timeout, source_id: source_id))
    push_data(data, options)
  end

  def get_data(options={})
    query_url = get_query_url(options)
    Maremma.get(query_url, options)
  end

  def url
    ENV['API_URL'] + "/dois?"
  end

  def timeout
    120
  end

  def job_batch_size
    1000
  end

  def send_notification_to_slack(text, options={})
    return nil unless options[:slack_webhook_url].present?

    attachment = {
      title: options[:title] || "Report",
      text: text,
      color: options[:level] || "good"
    }

    notifier = Slack::Notifier.new options[:slack_webhook_url],
                                    username: "Event Data Agent",
                                    icon_url: ICON_URL
    response = notifier.post attachments: [attachment]
    response.first
  end

  def self.doi_from_url(url)
    if /\A(?:(http|https):\/\/(dx\.)?(doi.org|handle.test.datacite.org)\/)?(doi:)?(10\.\d{4,5}\/.+)\z/.match(url)
      uri = Addressable::URI.parse(url)
      uri.path.gsub(/^\//, '').downcase
    end
  end

  def self.parse_attributes(element, options={})
    content = options[:content] || "__content__"

    if element.is_a?(String)
      element
    elsif element.is_a?(Hash)
      element.fetch(content, nil)
    elsif element.is_a?(Array)
      a = element.map { |e| e.is_a?(Hash) ? e.fetch(content, nil) : e }.uniq
      a = options[:first] ? a.first : a.unwrap
    else
      nil
    end
  end

  def self.to_schema_org(element)
    mapping = { "type" => "@type", "id" => "@id", "title" => "name" }

    map_hash_keys(element: element, mapping: mapping)
  end

  def self.to_schema_org_creators(element)
    element = Array.wrap(element).map do |c|
      c["affiliation"] = { "@type" => "Organization", "name" => c["affiliation"] } if c["affiliation"].present?
      c["@type"] = c["nameType"].present? ? c["nameType"][0..-3] : nil
      c["@id"] = Array.wrap(c["nameIdentifiers"]).first.to_h.fetch("nameIdentifier", nil)
      c["name"] = c["familyName"].present? ? [c["givenName"], c["familyName"]].join(" ") : c["name"]
      c.except("nameIdentifiers", "nameType").compact
    end.unwrap
  end

  def self.to_schema_org_container(element, options={})
    return nil unless element.is_a?(Hash) && (element["title"] || options[:container_title]).present?

    { 
      "@id" => normalize_doi(element["identifier"]) || element["identifier"],
      "@type" => (options[:type] == "Dataset") ? "DataCatalog" : "Periodical",
      "name" => element["title"] || options[:container_title] }.compact
  end

  def self.to_schema_org_funder(funding_references)
    return nil unless funding_references.present?

    Array.wrap(funding_references).map do |fr|
      {
        "@id" => fr["funderIdentifier"],
        "@type" => "Organization",
        "name" => fr["funderName"] }.compact
    end.unwrap
  end

  def self.map_hash_keys(element: nil, mapping: nil)
    Array.wrap(element).map do |a|
      a.map {|k, v| [mapping.fetch(k, k), v] }.reduce({}) do |hsh, (k, v)|
        if v.is_a?(Hash)
          hsh[k] = to_schema_org(v)
          hsh
        else
          hsh[k] = v
          hsh
        end
      end
    end.unwrap
  end

  def self.get_date(dates, date_type)
    dd = Array.wrap(dates).find { |d| d["dateType"] == date_type } || {}
    dd.fetch("date", nil)
  end

  def self.get_datacite_xml(id)
    logger = Logger.new(STDOUT)

    doi = doi_from_url(id)
    unless doi.present?
      logger.info "#{id} is not a valid DOI"
      return {}
    end

    url = ENV['API_URL'] + "/dois/#{doi}"
    response = Maremma.get(url)

    if response.status != 200
      logger.info "DOI #{doi} not found"
      return {}
    end
    
    xml = response.body.dig("data", "attributes", "xml")
    xml = Base64.decode64(xml) if xml.present?
    Maremma.from_xml(xml).to_h.fetch("resource", {})
  end

  def self.get_datacite_json(id)
    logger = Logger.new(STDOUT)

    doi = doi_from_url(id)
    unless doi.present?
      logger.info "#{id} is not a valid DOI"
      return {}
    end

    url = ENV['API_URL'] + "/dois/#{doi}"
    response = Maremma.get(url)

    if response.status != 200
      logger.info "DOI #{doi} not found"
      return {}
    end
    
    (response.body.dig("data", "attributes") || {}).except("xml")
  end

  def self.get_datacite_metadata(id)
    doi = doi_from_url(id)
    return {} unless doi.present?

    url = ENV['API_URL'] + "/dois/#{doi}"
    response = Maremma.get(url)
    return {} if response.status != 200

    parse_datacite_metadata(id: id, response: response)
  end          

  def self.get_crossref_metadata(id)
    doi = doi_from_url(id)
    return {} unless doi.present?

    # use metadata stored with DataCite if they exist
    response = get_datacite_metadata(id)
    return response if response.present?

    # otherwise store Crossref metadata with DataCite 
    # using client crossref.citations and DataCite XML
    xml = Base64.strict_encode64(id)
    attributes = {
      "xml" => xml,
      "source" => "levriero",
      "event" => "publish" }.compact

    data = {
      "data" => {
        "type" => "dois",
        "attributes" => attributes,
        "relationships" => {
          "client" =>  {
            "data" => {
              "type" => "clients",
              "id" => "crossref.citations"
            }
          }
        }
      }
    }

    url = ENV['API_URL'] + "/dois/#{doi}"
    response = Maremma.put(url, accept: 'application/vnd.api+json', 
                                content_type: 'application/vnd.api+json',
                                data: data.to_json, 
                                bearer: ENV["LAGOTTINO_TOKEN"])

    return {} unless [200, 201].include?(response.status)
    parse_datacite_metadata(id: id, response: response)
  end

  def self.parse_datacite_metadata(id: nil, response: nil)
    attributes = response.body.dig("data", "attributes")
    relationships = response.body.dig("data", "relationships")
    
    client_id = relationships.dig("client", "data", "id")
    publisher = attributes["publisher"].present? ? { "@type" => "Organization", "name" => attributes["publisher"] } : nil
    proxy_identifiers = Array.wrap(attributes["relatedIdentifiers"]).select { |ri| ["IsVersionOf", "IsIdenticalTo", "IsPartOf", "IsSupplementTo"].include?(ri["relationType"]) }. map do |ri|
      ri["relatedIdentifier"]
    end
    type = attributes.dig("types", "schemaOrg")

    {
      "@id" => id,
      "@type" => type,
      "name" => parse_attributes(attributes["titles"], content: "title", first: true),
      "author" => Array.wrap(to_schema_org_creators(attributes["creators"])),
      "publisher" => publisher,
      "periodical" => (type != "Dataset") && attributes["container"] ? to_schema_org_container(attributes["container"]) : nil,
      "includedInDataCatalog" => (type == "Dataset") && attributes["container"] ? to_schema_org_container(attributes["container"], type: "Dataset") : nil,
      "version" => attributes["version"],
      "datePublished" => get_date(attributes["dates"], "Issued"),
      "dateModified" => attributes["updated"],
      "funder" => to_schema_org_funder(attributes["fundingReferences"]),
      "proxyIdentifiers" => proxy_identifiers,
      "registrantId" => "datacite.#{client_id}" }.compact
  end

  def self.get_orcid_metadata(id)
    orcid = orcid_from_url(id)
    return {} unless orcid.present?

    url = ENV['ORCID_API_URL'] + "/#{orcid}/person"
    response = Maremma.get(url, accept: "application/vnd.orcid+json")
    return {} if response.status != 200

    data = response.body.fetch("data", {})

    {
      "@id" => id,
      "@type" => "Person",
      "givenName" => data.dig("name", "given-names", "value"),
      "familyName" => data.dig("name", "family-name", "value"),
      "name" => data.dig("name", "credit-name", "value") }.compact
  end

  def unfreeze(hsh)
    new_hash = {}
    hsh.each_pair { |k,v| new_hash.merge!({k.downcase.to_sym => v})  }
    new_hash
  end
end