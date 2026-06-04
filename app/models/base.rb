require "bolognese"

class Base
  include Importable
  include Cacheable
  include ::Bolognese::MetadataUtils

  # icon for Slack messages
  ICON_URL = "https://raw.githubusercontent.com/datacite/toccatore/master/lib/toccatore/images/toccatore.png".freeze

  def queue(_options = {})
    Rails.logger.error "Queue name has not been specified" if ENV["ENVIRONMENT"].blank?
    Rails.logger.error "AWS_REGION has not been specified" if ENV["AWS_REGION"].blank?
    region = ENV["AWS_REGION"] ||= "eu-west-1"
    Aws::SQS::Client.new(region: region.to_s, stub_responses: false)
  end

  def get_message(_options = {})
    sqs.receive_message(queue_url: queue_url, max_number_of_messages: 1,
                        wait_time_seconds: 1)
  end

  def delete_message(message)
    response = sqs.delete_message({
                                    queue_url: queue_url,
                                    receipt_handle: message[:receipt_handle],
                                  })
    if response.successful?
      Rails.logger.info "Message #{message[:receipt_handle]} deleted"
    else
      Rails.logger.error "Could not delete Message #{message[:receipt_handle]}"
    end
  end

  def queue_url(options = {})
    options[:queue_name] ||= "#{ENV['ENVIRONMENT']}_usage"
    queue_name = options[:queue_name]
    # puts "Using  #{sqs.get_queue_url(queue_name: queue_name).queue_url} queue"
    sqs.get_queue_url(queue_name: queue_name).queue_url
  end

  def get_query_url(options = {})
    options[:number] ||= 1
    options[:size] ||= 1000
    updated = "updated:[#{options[:from_date]}T00:00:00Z TO #{options[:until_date]}T23:59:59Z]"
    options[:exclude_registration_agencies] ||= true
    options[:resource_type_id] ||= ""

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
      query: "#{query} AND #{updated}",
      "resource-type-id" => options[:resource_type_id],
      "page[number]" => options[:number],
      "page[size]" => options[:size],
      "exclude_registration_agencies" => options[:exclude_registration_agencies],
      affiliation: true,
    }

    url + URI.encode_www_form(params)
  end

  def get_total(options = {})
    query_url = get_query_url(options.merge(size: 0))
    result = Maremma.get(query_url, options)
    result.body.dig("meta", "total").to_i
  end

  def queue_jobs(options = {})
    options[:number] = options[:number].to_i || 1
    options[:size] = options[:size].presence || job_batch_size
    options[:from_date] =
      options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
    options[:until_date] =
      options[:until_date].presence || Time.now.to_date.iso8601
    options[:content_type] = "json"

    total = get_total(options)

    if total.positive?
      # walk through results paginated via cursor, unless test environment
      total_pages = Rails.env.test? ? 1 : (total.to_f / job_batch_size).ceil
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

    Rails.logger.info text

    # send slack notification
    options[:level] = if total.zero?
                        "warning"
                      elsif error_total.positive?
                        "danger"
                      else
                        "good"
                      end
    options[:title] = "Report for #{source_id}"
    if options[:slack_webhook_url].present?
      send_notification_to_slack(text,
                                 options)
    end

    # return number of dois queued
    total
  end

  def process_data(options = {})
    data = get_data(options.merge(timeout: timeout, source_id: source_id))
    push_data(data, options)
  end

  def get_data(options = {})
    query_url = get_query_url(options)
    Maremma.get(query_url, options)
  end

  def url
    "#{ENV['API_URL']}/dois?"
  end

  def timeout
    120
  end

  def job_batch_size
    Rails.env.test? ? 25 : 1000
  end

  def send_notification_to_slack(text, options = {})
    return nil if options[:slack_webhook_url].blank?

    attachment = {
      title: options[:title] || "Report",
      text: text,
      color: options[:level] || "good",
    }

    notifier = Slack::Notifier.new options[:slack_webhook_url],
                                   username: "Event Data Agent",
                                   icon_url: ICON_URL
    response = notifier.post attachments: [attachment]
    response.first
  end

  def self.doi_from_url(url)
    if /\A(?:(http|https):\/\/(dx\.)?(doi.org|handle.test.datacite.org|handle.stage.datacite.org)\/)?(doi:)?(10\.\d{4,5}\/.+)\z/.match?(url)
      uri = Addressable::URI.parse(url)
      uri.path.gsub(/^\//, "").downcase
    end
  end

  def self.parse_attributes(element, options = {})
    content = options[:content] || "__content__"

    case element
    when String
      element
    when Hash
      element.fetch(content, nil)
    when Array
      a = element.map { |e| e.is_a?(Hash) ? e.fetch(content, nil) : e }.uniq
      a = options[:first] ? a.first : a.unwrap
    end
  end

  def self.to_schema_org(element)
    mapping = { "type" => "@type", "id" => "@id", "title" => "name" }

    map_hash_keys(element: element, mapping: mapping)
  end

  def self.map_hash_keys(element: nil, mapping: nil)
    Array.wrap(element).map do |a|
      a.map { |k, v| [mapping.fetch(k, k), v] }.reduce({}) do |hsh, (k, v)|
        hsh[k] = if v.is_a?(Hash)
                   to_schema_org(v)
                 else
                   v
                 end

        hsh
      end
    end.unwrap
  end

  def self.get_date(dates, date_type)
    dd = Array.wrap(dates).detect { |d| d["dateType"] == date_type } || {}
    dd.fetch("date", nil)
  end

  def self.get_date_from_date_parts(date_as_parts)
    date_parts = date_as_parts.fetch("date-parts", []).first
    year = date_parts[0]
    month = date_parts[1]
    day = date_parts[2]
    get_date_from_parts(year, month, day)
  end

  def self.get_date_from_parts(year, month = nil, day = nil)
    [year.to_s.rjust(4, "0"), month.to_s.rjust(2, "0"),
     day.to_s.rjust(2, "0")].reject do |part|
      part == "00"
    end.join("-")
  end

  def self.get_datacite_xml(id)
    doi = doi_from_url(id)
    if doi.blank?
      Rails.logger.error "#{id} is not a valid DOI"
      return {}
    end

    url = ENV["API_URL"] + "/dois/#{doi}"
    response = Maremma.get(url)

    if response.status != 200
      Rails.logger.info "DOI #{doi} not found"
      return {}
    end

    xml = response.body.dig("data", "attributes", "xml")
    xml = Base64.decode64(xml) if xml.present?
    Maremma.from_xml(xml).to_h.fetch("resource", {})
  end

  def self.get_datacite_json(id)
    doi = doi_from_url(id)
    if doi.blank?
      Rails.logger.error "#{id} is not a valid DOI"
      return {}
    end

    url = ENV["API_URL"] + "/dois/#{doi}?affiliation=true"
    response = Maremma.get(url)

    if response.status != 200
      Rails.logger.info "DOI #{doi} not found"
      return {}
    end

    attributes = (response.body.dig("data", "attributes") || {}).except("xml")
    relationships = response.body.dig("data", "relationships") || {}

    attributes.merge("relationships" => relationships)
  end

  def self.get_client(id)
    url = ENV["API_URL"] + "/clients/#{id}"
    response = Maremma.get(url)
    return {} if response.status != 200

    response.body.dig("data", "attributes") || {}
  end

  def self.raid_registry_record?(attributes)
    client_id = attributes.dig("relationships", "client", "data", "id")
    return false if client_id.blank?

    client = cached_client(client_id)
    return false if client.blank?

    client.dig("clientType") == "raidRegistry"
  end

  def self.get_datacite_metadata(id)
    doi = doi_from_url(id)
    return {} if doi.blank?

    url = ENV["API_URL"] + "/dois/#{doi}"
    response = Maremma.get(url)
    return {} if response.status != 200

    parse_datacite_metadata(id: id, response: response)
  end

  def self.get_crossref_metadata(id)
    doi = doi_from_url(id)
    return {} if doi.blank?

    url = "https://api.crossref.org/works/#{Addressable::URI.encode(doi)}?mailto=info@datacite.org"
    sleep(0.24) # to avoid crossref rate limitting
    response =  Maremma.get(url, host: true)
    return {} if response.status != 200

    meta = response.body.dig("data", "message")

    case meta.fetch("type", nil)
    when "dataset"
      type = "Dataset"
    when "other"
    when "peer-review"
    when "journal"
    when "journal-volume"
      type = "Other"
    else
      type = "ScholarlyArticle"
    end

    date_published = if meta.dig("issued", "date-parts")
                       get_date_from_date_parts(meta["issued"])
                       # elsif

                     end

    {
      "@id" => id,
      "@type" => type,
      "datePublished" => date_published,
      "registrantId" => meta["member"].present? ? "crossref.#{meta['member']}" : nil,
    }.compact
  end

  def self.parse_datacite_metadata(id: nil, response: nil)
    attributes = response.body.dig("data", "attributes")
    relationships = response.body.dig("data", "relationships")

    client_id = relationships.dig("client", "data", "id")
    publisher = if attributes["publisher"].present?
                  { "@type" => "Organization",
                    "name" => attributes["publisher"] }
                end
    proxy_identifiers = Array.wrap(attributes["relatedIdentifiers"]).select do |ri|
      ["IsVersionOf", "IsIdenticalTo", "IsPartOf",
       "IsSupplementTo"].include?(ri["relationType"])
    end.pluck("relatedIdentifier")
    resource_type_general = attributes.dig("types", "resourceTypeGeneral")
    type = Bolognese::Utils::DC_TO_SO_TRANSLATIONS[resource_type_general.to_s.dasherize] # || attributes.dig("types", "schemaOrg")

    registrant_id = client_id == "crossref.citations" ? cached_crossref_member_id(id) : "datacite.#{client_id}"

    {
      "@id" => id,
      "@type" => type,
      "datePublished" => get_date(attributes["dates"], "Issued"),
      "proxyIdentifiers" => proxy_identifiers,
      "registrantId" => registrant_id,
    }.compact
  end

  def self.get_crossref_member_id(id, _options = {})
    doi = doi_from_url(id)
    # return "crossref.citations" unless doi.present?

    url = "https://api.crossref.org/works/#{Addressable::URI.encode(doi)}?mailto=info@datacite.org"
    sleep(0.24) # to avoid crossref rate limitting
    response =  Maremma.get(url, host: true)
    Rails.logger.debug "[Crossref Response] [#{response.status}] for DOI #{doi} metadata"
    return "crossref.citations" if response.status != 200

    message = response.body.dig("data", "message")

    "crossref.#{message['member']}"
  end

  def self.get_researcher_metadata(id)
    orcid = orcid_from_url(id)
    return {} if orcid.blank?

    url = ENV["API_URL"] + "/users/#{orcid}"
    response = Maremma.get(url)
    return {} if response.status != 200

    # parse_researcher_metadata(id: id, response: response)
    {
      "@id" => "https://orcid.org/#{response.body.dig('data', 'id')}",
      "@type" => "Person",
    }.compact
  end

  def self.get_orcid_metadata(id)
    # use metadata stored with DataCite if they exist
    response = get_researcher_metadata(id)
    return response if response.present?

    # otherwise store ORCID metadata with DataCite
    orcid = orcid_from_url(id)
    return {} if orcid.blank?

    url = ENV["ORCID_API_URL"] + "/#{orcid}/person"
    response = Maremma.get(url, accept: "application/vnd.orcid+json")
    return {} if response.status != 200

    message = response.body.fetch("data", {})
    attributes = parse_message(message: message)
    data = {
      "data" => {
        "type" => "users",
        "attributes" => attributes,
      },
    }
    url = ENV["VOLPINO_URL"] + "/users/#{orcid}"
    response = Maremma.put(url, accept: "application/vnd.api+json",
                                content_type: "application/vnd.api+json",
                                data: data.to_json,
                                bearer: ENV["STAFF_PROFILES_ADMIN_TOKEN"])

    if [200, 201].include?(response.status)
      Rails.logger.info "[Event Data] User #{orcid} created in Profiles service."
    elsif response.status == 409
      Rails.logger.info "[Event Data] User #{orcid} already existed in Profiles service."
    elsif response.body["errors"].present?
      Rails.logger.error "[Event Data] Creating user #{orcid} had an error: #{response.body['errors']}"
    end

    return {} unless [200, 201].include?(response.status)

    {
      "@id" => "https://orcid.org/#{orcid}",
      "@type" => "Person",
    }.compact
  end

  def self.parse_message(message: nil)
    given_names = message.dig("name", "given-names", "value")
    family_name = message.dig("name", "family-name", "value")

    name = if message.dig("name", "credit-name", "value").present?
             message.dig("name", "credit-name", "value")
           elsif given_names.present? || family_name.present?
             [given_names, family_name].join(" ")
           end

    {
      "name" => name,
      "givenNames" => given_names,
      "familyName" => family_name,
    }.compact
  end

  def unfreeze(hsh)
    new_hash = {}
    hsh.each_pair { |k, v| new_hash.merge!({ k.downcase.to_sym => v }) }
    new_hash
  end
end
