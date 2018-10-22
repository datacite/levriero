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

    reponse = sqs.delete_message({
      queue_url: queue_url,
      receipt_handle: message[:receipt_handle]    
    })
    if reponse.successful?
      logger.info "Message #{message[:receipt_handle]} deleted"
    else
      logger.info "Could NOT delete Message #{message[:receipt_handle]}"
    end
  end

  def queue_url options={}
    options[:queue_name] ||= "#{ENV['ENVIRONMENT']}_usage" 
    queue_name = options[:queue_name] 
    # puts "Using  #{sqs.get_queue_url(queue_name: queue_name).queue_url} queue"
    sqs.get_queue_url(queue_name: queue_name).queue_url
  end
  
  def get_query_url(options={})
    updated = "updated:[#{options[:from_date]}T00:00:00Z TO #{options[:until_date]}T23:59:59Z]"
    fq = "#{updated} AND has_metadata:true AND is_active:true"

    if options[:doi].present?
      q = "doi:#{options[:doi]}"
    elsif options[:orcid].present?
      q = "nameIdentifier:ORCID\\:#{options[:orcid]}"
    elsif options[:related_identifier].present?
      q = "relatedIdentifier:DOI\\:#{options[:related_identifier]}"
    elsif options[:query].present?
      q = options[:query]
    else
      q = query
    end

    params = { 
      q: q,
      start: options[:offset],
      rows: options[:rows],
      fl: "doi,relatedIdentifier,nameIdentifier,funderIdentifier,minted,updated",
      fq: fq,
      wt: "json" }

    url +  URI.encode_www_form(params)
  end

  def get_total(options={})
    query_url = get_query_url(options.merge(rows: 0))
    result = Maremma.get(query_url, options)
    result.body.fetch("data", {}).fetch("response", {}).fetch("numFound", 0)
  end

  def queue_jobs(options={})
    logger = Logger.new(STDOUT)

    options[:offset] = options[:offset].to_i || 0
    options[:rows] = options[:rows].presence || job_batch_size
    options[:from_date] = options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
    options[:until_date] = options[:until_date].presence || Time.now.to_date.iso8601
    options[:content_type] = 'json'

    total = get_total(options)

    if total > 0
      # walk through paginated results
      total_pages = (total.to_f / job_batch_size).ceil
      error_total = 0

      (0...total_pages).each do |page|
        options[:offset] = page * job_batch_size
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

    # return number of works queued
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
    ENV['SOLR_URL'] + "/api?"
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
    Maremma.from_xml(xml).fetch("resource", {})
  end

  def self.get_datacite_metadata(id)
    doi = doi_from_url(id)
    return {} unless doi.present?

    url = ENV['API_URL'] + "/dois/#{doi}"
    response = Maremma.get(url)
    return {} if response.status != 200
    
    attributes = response.body.dig("data", "attributes")
    relationships = response.body.dig("data", "relationships")

    resource_type = response.body.dig("data", "relationships")
    resource_type_general = relationships.dig("resource-type", "data", "id")
    type = Bolognese::Utils::CR_TO_SO_TRANSLATIONS[resource_type.to_s.underscore.camelcase] || Bolognese::Utils::DC_TO_SO_TRANSLATIONS[resource_type_general.to_s.underscore.camelcase(first_letter = :upper)] || "CreativeWork"
    author = Array.wrap(attributes["author"]).map do |a| 
      {
        "given_name" => a["givenName"],
        "family_name" => a["familyName"],
        "name" => a["familyName"].present? ? nil : a["name"] }.compact
    end
    client_id = relationships.dig("client", "data", "id")

    {
      "id" => id,
      "type" => type.underscore.dasherize,
      "name" => attributes["title"],
      "author" => author,
      "publisher" => attributes["publisher"],
      "version" => attributes["version"],
      "date_published" => attributes["published"],
      "date_modified" => attributes["updated"],
      "registrant_id" => "datacite.#{client_id}" }.compact
  end

  def self.get_crossref_metadata(id)
    doi = doi_from_url(id)
    return {} unless doi.present?

    url = "https://api.crossref.org/works/#{doi}"
    response = Maremma.get(url, host: true)

    return {} if response.status != 200
    
    message = response.body.dig("data", "message")

    type = Bolognese::Utils::CR_TO_SO_TRANSLATIONS[message["type"].underscore.camelize] || "creative-work"
    author = Array.wrap(message["author"]).map do |a| 
      {
        "given_name" => a["given"],
        "family_name" => a["family"],
        "name" => a["name"] }.compact
    end

    {
      "id" => id,
      "type" => type.underscore.dasherize,
      "name" => Array.wrap(message["title"]).first,
      "author" => author,
      "periodical" => Array.wrap(message["container-title"]).first,
      "volume_number" => message["volume"],
      "issue_number" => message["issue"],
      "pagination" => message["page"],
      "publisher" => message["publisher"],
      "issn" => message["ISSN"],
      "date_published" => Base.new.get_date_from_date_parts(message["issued"]),
      "date_modified" => message.dig("indexed", "date-time"),
      "registrant_id" => "crossref.#{message["member"]}" }.compact
  end

  def unfreeze(hsh)
    new_hash = {}
    hsh.each_pair { |k,v| new_hash.merge!({k.downcase.to_sym => v})  }
    new_hash
  end
end