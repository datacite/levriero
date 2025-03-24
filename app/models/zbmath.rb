# frozen_string_literal: true

include Bolognese::MetadataUtils
class Zbmath
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"

  include Queueable

  include Cacheable

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      ZbmathImportByMonthJob.perform_later(from_date: m.strftime("%F"),
                                           until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for ZBMath Records updated from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current
    Rails.logger.info "Importing ZBMath Records updated from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
    zbmath = Zbmath.new
    zbmath.get_records(from: from_date.strftime("%F"), until: until_date.strftime("%F"))
  end

  def source_id
    "zbmath"
  end

  def get_records(options = {})
    client = OAI::Client.new "https://oai.portal.mardi4nfdi.de/oai/OAIHandler"
    count = 0
    begin
      # Get the metadata - read_datacite expects a string of the XML tree with the <resource> element as the root,
      # and OAI wraps the data in a <metadata> element so strip this with string slicing (a little ugly, but a lot
      # simpler and more efficient than parsing the XML, restructuring the tree and then serializing back to string).
      #
      # Using the .full.each pattern allows transparent handling of the resumption token pattern in the OAI protocol
      # rather than having to deal with it manually. The client should only load one page into memory ay a time, so the
      # efficiency should be ok.
      response = client.list_records(metadata_prefix: "datacite_articles", from: options[:from],
                                     until: options[:until]).full.each do |record|
        ZbmathImportJob.perform_later(record.metadata.to_s[12..-14])
        count += 1
      end
      count
    rescue OAI::NoMatchException
      Rails.logger.info "No ZBMath records updated between #{options[:from]} and #{options[:until]}."
      nil
    end
  end

  def self.parse_zbmath_record(record)
    meta = read_datacite(string: record)

    # Check that the record is for a DataCite DOI
    doi = meta.fetch("doi", nil)
    return nil if doi.blank? # && cached_doi_ra(doi) == "DataCite"

    pid = normalize_doi(doi)
    subj = cached_datacite_response(pid)
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
        ra = cached_doi_ra(related_identifier)
        obj = if ra == "DataCite"
                cached_datacite_response(obj_id)
              elsif ra == "Crossref"
                cached_crossref_response(obj_id)
              else
                {}
              end
      else
        # It's a URL so no PID object on the other end
        obj_id = normalize_url(related_identifier)
        obj = {}
      end

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
      # TODO: Move source token to an ENV variable
      x
    end

    # extract creator identifiers
    creator_identifiers = Array.wrap(meta.fetch("creators", nil)).select do |c|
      c["nameIdentifiers"].present? && c["nameIdentifiers"].any? do |n|
        n["nameIdentifierScheme"] == "zbMATH Author Code"
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
               "subj_id" => pid,
               "obj_id" => "https://zbmath.org/authors/#{n['nameIdentifier']}",
               "relation_type_id" => "is_authored_by",
               "source_id" => "zbmath_author",
               "occurred_at" => Time.zone.now.utc,
               "timestamp" => Time.zone.now.iso8601,
               "license" => LICENSE,
               "subj" => subj,
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
             "subj_id" => pid,
             "obj_id" => item_url,
             "relation_type_id" => "is_identical_to",
             "source_id" => "zbmath_identifier",
             "occurred_at" => Time.zone.now.utc,
             "timestamp" => Time.zone.now.iso8601,
             "license" => LICENSE,
             "subj" => subj,
             "obj" => {},
             "source_token" => ENV["ZBMATH_IDENTIFIER_SOURCE_TOKEN"] || "9908552f-593b-4825-817e-bca48644624b" }
      x
    end)

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
