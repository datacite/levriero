class Base
  include Importable

  # icon for Slack messages
  ICON_URL = "https://raw.githubusercontent.com/datacite/toccatore/master/lib/toccatore/images/toccatore.png"

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
      fl: "doi,resourceTypeGeneral,relatedIdentifier,nameIdentifier,minted,updated",
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
    options[:offset] = options[:offset].to_i || 0
    options[:rows] = options[:rows].presence || job_batch_size
    options[:from_date] = options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
    options[:until_date] = options[:until_date].presence || Time.now.to_date.iso8601

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
      text = "Queued import for #{total} DOIs updated #{options[:from_date]} - #{options[:until_date]}."
    else
      text = "No DOIs updated #{options[:from_date]} - #{options[:until_date]}."
    end

    Rails.logger.info text

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

  # parse author string into CSL format
  # only assume personal name when using sort-order: "Turing, Alan"
  def get_one_author(author)
    return { "literal" => "" } if author.strip.blank?

    author = cleanup_author(author)
    names = Namae.parse(author)

    if names.blank? || is_personal_name?(author).blank?
      { "literal" => author }
    else
      name = names.first

      { "family" => name.family,
        "given" => name.given }.compact
    end
  end

  def cleanup_author(author)
    # detect pattern "Smith J.", but not "Smith, John K."
    author = author.gsub(/[[:space:]]([A-Z]\.)?(-?[A-Z]\.)$/, ', \1\2') unless author.include?(",")

    # titleize strings
    # remove non-standard space characters
    author.my_titleize
          .gsub(/[[:space:]]/, ' ')
  end

  def is_personal_name?(author)
    return true if author.include?(",")

    # lookup given name
    name_detector.name_exists?(author.split.first)
  end

  # parse array of author strings into CSL format
  def get_authors(authors, options={})
    Array(authors).map { |author| get_one_author(author) }
  end

  # parse array of author hashes into CSL format
  def get_hashed_authors(authors)
    Array(authors).map { |author| get_one_hashed_author(author) }
  end

  def get_one_hashed_author(author)
    raw_name = author.fetch("creatorName", nil)

    author_hsh = get_one_author(raw_name)
    author_hsh["ORCID"] = get_name_identifier(author)
    author_hsh.compact
  end

  def get_name_identifier(author)
    name_identifier = author.fetch("nameIdentifier", nil)
    name_identifier_scheme = author.fetch("nameIdentifierScheme", "orcid").downcase
    if name_identifier_scheme == "orcid" && name_identifier = validate_orcid(name_identifier)
      "http://orcid.org/#{name_identifier}"
    else
      nil
    end
  end

  def name_detector
    GenderDetector.new
  end

  def unfreeze(hsh)
    new_hash = {}
    hsh.each_pair { |k,v| new_hash.merge!({k.downcase.to_sym => v})  }
    new_hash
  end
end

class String
  def my_titleize
    self.gsub(/(\b|_)(.)/) { "#{$1}#{$2.upcase}" }
  end
end