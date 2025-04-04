# frozen_string_literal: true

include Bolognese::MetadataUtils
class ZbmathArticle
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"
  ARXIV_PREFIX = ENV["ARXIV_PREFIX"] || "10.48550"

  include Queueable

  include Cacheable

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? DateTime.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? DateTime.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      ZbmathArticleImportByMonthJob.perform_later(from_date: m.strftime("%F"),
                                                  until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for ZBMath Article Records updated from #{from_date} until #{until_date}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? DateTime.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? DateTime.parse(options[:until_date]) : Date.current
    Rails.logger.info "Importing ZBMath Article Records updated from #{from_date} until #{until_date}."
    zbmath = ZbmathArticle.new
    zbmath.get_records(from: from_date, until: until_date)
  end

  def source_id
    "zbmath"
  end

  def check_for_arxiv(record)
    # Check if the record has an ARXIV identifier as the primary identifier and convert it to a DOI
    identifier = record.xpath_first(record._source, ".//metadata/resource/identifier")
    if identifier && identifier.attributes.fetch("identifierType").value.downcase == "arxiv"
      arxiv_identifier = if identifier.text.downcase.start_with?("arxiv:")
                           "arXiv.#{identifier.text[6..]}"
                         else
                           "arXiv.#{identifier.text}"
                         end
      "#{ARXIV_PREFIX}/#{arxiv_identifier}"
    end
  end

  def remove_extra_identifiers(record)
    # If the record has more than one <identifier> element, bolognese will error out, so as a workaround we remove all but the first
    identifiers = record.metadata.get_elements("//resource/identifier")
    if identifiers.size > 1
      identifiers[1..].each { |i| record.metadata.children[0].delete_element(i) }
    end
    record
  end

  def get_records(options = {})
    count = 0
    client = OAI::Client.new "https://oai.portal.mardi4nfdi.de/oai/OAIHandler"
    begin
      # Using the .full.each pattern allows transparent handling of the resumption token pattern in the OAI protocol
      # rather than having to deal with it manually. The client should only load one page into memory at a time, so the
      # efficiency should be ok.
      client.list_identifiers(metadata_prefix: "datacite_articles", from: options[:from],
                              until: options[:until]).full.each do |record|
        ZbmathArticleImportJob.perform_later(record.identifier)
        count += 1
      end
    rescue OAI::NoMatchException
      Rails.logger.info "No ZBMath Article records updated between #{options[:from]} and #{options[:until]}."
      return nil
    end
    count
  end

  def get_zbmath_record(identifier)
    client = OAI::Client.new "https://oai.portal.mardi4nfdi.de/oai/OAIHandler"
    begin
      response = client.get_record(identifier: identifier, metadata_prefix: "datacite_articles")
      response.record
    rescue OAI::IdException
      Rails.logger.info "ZBMath Article records #{identifier} not found in the OAI server."
      nil
    end
  end

  def self.process_zbmath_record(identifier)
    # Get the record
    z = ZbmathArticle.new
    record = z.get_zbmath_record(identifier)
    return nil if record.nil?

    # Check if the record has a DOI via arXiv as the primary identifier to be passed into the read_datacite method
    arxiv_doi = z.check_for_arxiv(record)

    # Remove any extra identifiers to avoid bolognese errors
    record = z.remove_extra_identifiers(record)

    # Get the metadata - read_datacite expects a string of the XML tree with the <resource> element as the root,
    # and OAI wraps the data in a <metadata> element so strip this with string slicing (a little ugly, but a lot
    # simpler and more efficient than parsing the XML, restructuring the tree and then serializing back to string).
    meta = read_datacite(string: record.metadata.to_s[10..-12], doi: arxiv_doi)

    # Extract any arXiv identifiers from the related_identifiers metadata to potentially fill in for a missing DOI
    arxiv_identifier = nil
    if arxiv_doi.blank?
      arxiv_identifier = meta.fetch("identifiers", []).detect do |r|
        r["identifierType"].downcase == "arxiv"
      end&.fetch("identifier", nil)
      if arxiv_identifier.present?
        unless arxiv_identifier.start_with?("arxiv:")
          arxiv_identifier = "arXiv.#{arxiv_identifier}"
        end
        "#{ARXIV_PREFIX}/#{arxiv_identifier}"
      end
    end

    if arxiv_identifier.blank?
      # Check if there's an an arXiv identifier in the "zbMATH identifier" value
      zbmath_identifier = meta.fetch("identifiers", []).detect do |r|
        r["identifierType"] == "zbMATH Identifier"
      end&.fetch("identifier", nil)
      if zbmath_identifier.present? && zbmath_identifier.downcase.start_with?("arxiv:")
        arxiv_identifier = "#{ARXIV_PREFIX}/arxiv.#{zbmath_identifier[6..]}"
      end
    end

    # Check if the record has a DOI
    doi = meta.fetch("doi", nil)

    if doi.blank? && arxiv_identifier.present?
      doi = arxiv_identifier
    end

    return nil if doi.blank?

    # Populate information about the DOI for use in events
    ra = cached_doi_ra(doi)
    pid = normalize_doi(doi)

    subj = if ra == "DataCite"
             cached_datacite_response(pid)
           elsif ra == "Crossref"
             cached_crossref_response(pid)
           else
             {}
           end

    # If there's an arXiv identifier as well, populate information for use in adding events
    arxiv_pid = arxiv_identifier.present? && arxiv_identifier.downcase != doi.downcase ? normalize_doi(arxiv_identifier) : nil
    arxiv_subj = arxiv_pid.present? ? cached_datacite_response(arxiv_pid) : {}

    # parse out valid related identifiers
    related_doi_identifiers = Array.wrap(meta.fetch("related_identifiers", nil)).select do |r|
      %w(DOI URL).include?(r["relatedIdentifierType"]) && r["relatedIdentifier"] != "https://zbmath.org"
    end

    # loop through related identifiers and build event objects
    items = Array.wrap(related_doi_identifiers).reduce([]) do |x, item|
      related_identifier = item.fetch("relatedIdentifier", nil).to_s.strip.downcase
      related_identifier_type = item.fetch("relatedIdentifierType", nil).to_s.strip

      if related_identifier_type == "DOI"
        obj_id = normalize_doi(related_identifier)
        # Get RA and populate obj
        related_ra = cached_doi_ra(related_identifier)
        obj = if related_ra == "DataCite"
                cached_datacite_response(obj_id)
              elsif related_ra == "Crossref"
                # Don't bother hitting Crossref API if we won't process the relationship
                if ra == "DataCite" || arxiv_pid.present?
                  cached_crossref_response(obj_id)
                else
                  {}
                end
              else
                {}
              end
      else
        # It's a URL so no PID object on the other end
        obj_id = normalize_url(related_identifier)
        obj = {}
        related_ra = nil
      end

      # Add DataCite <-> Other events
      if ra == "DataCite" || related_ra == "DataCite"
        x << { "message_action" => "create",
               "id" => SecureRandom.uuid,
               "subj_id" => pid,
               "obj_id" => obj_id,
               "relation_type_id" => item["relationType"].to_s.underscore,
               "source_id" => "zbmath_related",
               "occurred_at" => Time.zone.now.utc,
               "timestamp" => Time.zone.now.iso8601,
               "license" => LICENSE,
               "subj" => subj,
               "obj" => obj,
               "source_token" => ENV["ZBMATH_RELATED_SOURCE_TOKEN"] || "4c891c31-519e-4d98-ac8d-876ad0f28635" }
      end

      if arxiv_pid.present?
        x << { "message_action" => "create",
               "id" => SecureRandom.uuid,
               "subj_id" => arxiv_pid,
               "obj_id" => obj_id,
               "relation_type_id" => item["relationType"].to_s.underscore,
               "source_id" => "zbmath_related",
               "occurred_at" => Time.zone.now.utc,
               "timestamp" => Time.zone.now.iso8601,
               "license" => LICENSE,
               "subj" => arxiv_subj,
               "obj" => obj,
               "source_token" => ENV["ZBMATH_RELATED_SOURCE_TOKEN"] || "4c891c31-519e-4d98-ac8d-876ad0f28635" }
      end
      x
    end

    if (ra == "DataCite") || arxiv_pid.present?
      # extract creator identifiers
      creator_identifiers = Array.wrap(meta.fetch("creators", nil)).select do |c|
        c["nameIdentifiers"].present? && c["nameIdentifiers"].any? do |n|
          n["nameIdentifierScheme"] == "zbMATH Author Code" && n["nameIdentifier"] != ":unav"
        end
      end

      # loop through creator identifiers, build event objects and add them to the event array
      items.concat(Array.wrap(creator_identifiers).reduce([]) do |x, item|
        name_identifiers = Array.wrap(item.fetch("nameIdentifiers", nil)).select do |n|
          n["nameIdentifierScheme"] == "zbMATH Author Code"
        end
        name_identifiers.each do |n|
          x << { "message_action" => "create",
                 "id" => SecureRandom.uuid,
                 "subj_id" => ra == "DataCite" ? pid : arxiv_pid,
                 "obj_id" => "https://zbmath.org/authors/#{n['nameIdentifier']}",
                 "relation_type_id" => "is_authored_by",
                 "source_id" => "zbmath_author",
                 "occurred_at" => Time.zone.now.utc,
                 "timestamp" => Time.zone.now.iso8601,
                 "license" => LICENSE,
                 "subj" => ra == "DataCite" ? subj : arxiv_subj,
                 "obj" => {},
                 "source_token" => ENV["ZBMATH_AUTHOR_SOURCE_TOKEN"] || "759c2591-7161-4c17-8e35-b3e1a28b4568" }
        end
        x
      end)

      # gather alternate identifiers
      alternate_identifiers = Array.wrap(meta.fetch("identifiers", nil)).select do |a|
        ["zbMATH Identifier", "zbMATH Document ID", "URL"].include?(a["identifierType"])
      end

      # loop through alternate identifiers, build event objects and add them to the event array
      items.concat(Array.wrap(alternate_identifiers).reduce([]) do |x, item|
        item_url = if item["identifierType"] == "zbMATH Identifier"
                     "https://zbmath.org/#{item['identifier']}"
                   else
                     item["identifier"]
                   end
        x << { "message_action" => "create",
               "id" => SecureRandom.uuid,
               "subj_id" => ra == "DataCite" ? pid : arxiv_pid,
               "obj_id" => item_url,
               "relation_type_id" => "is_identical_to",
               "source_id" => "zbmath_identifier",
               "occurred_at" => Time.zone.now.utc,
               "timestamp" => Time.zone.now.iso8601,
               "license" => LICENSE,
               "subj" => ra == "DataCite" ? subj : arxiv_subj,
               "obj" => {},
               "source_token" => ENV["ZBMATH_IDENTIFIER_SOURCE_TOKEN"] || "9908552f-593b-4825-817e-bca48644624b" }

        x
      end)
    end
    # Loop items and send events to the queue
    Array.wrap(items).each do |item|
      data = {
        "data" => {
          "id" => item["id"],
          "type" => "events",
          "attributes" => {
            "messageAction" => item["message_action"],
            "subjId" => item["subj_id"],
            "objId" => item["obj_id"],
            "relationTypeId" => item["relation_type_id"].to_s.dasherize,
            "sourceId" => item["source_id"],
            "occurredAt" => item["occurred_at"],
            "timestamp" => item["timestamp"],
            "license" => item["license"],
            "subj" => item["subj"],
            "obj" => item["obj"],
            "sourceToken" => item["source_token"],
          },
        },
      }

      send_event_import_message(data)

      Rails.logger.info("[Event Data] #{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} sent to the events queue.")
    end
    items.length
  end
end
