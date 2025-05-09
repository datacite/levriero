# frozen_string_literal: true

include Bolognese::MetadataUtils
class ZbmathSoftware
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"
  ARXIV_PREFIX = ENV["ARXIV_PREFIX"] || "10.48550"

  include Queueable

  include Cacheable

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? DateTime.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? DateTime.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      ZbmathSoftwareImportByMonthJob.perform_later(from_date: m.strftime("%F"),
                                                   until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for ZBMath Software Records updated from #{from_date} until #{until_date}."
  end

  def self.import_by_day(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current)
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current)

    # queue a job for every day between from_date and until_date
    (from_date..until_date).each do |d|
      ZbmathSoftwareImportByDayJob.perform_later(from_date: d.strftime("%Y-%m-%dT00:00:00Z"),
                                                 until_date: d.strftime("%Y-%m-%dT23:59:59Z"))
    end

    "Queued import for ZBMath Software Records updated from #{from_date} until #{until_date}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? DateTime.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? DateTime.parse(options[:until_date]) : Date.current
    zbmath = ZbmathSoftware.new
    if options[:filename]
      filename = options[:filename]
      Rails.logger.info "Getting ZBMath Software record identifiers updated from #{from_date} until #{until_date} and writing to #{filename}."
      zbmath.get_records(from: from_date, until: until_date, filename: filename)
    else
      Rails.logger.info "Importing ZBMath Software Records updated from #{from_date} until #{until_date}."
      zbmath.get_records(from: from_date, until: until_date)
    end
  end

  def source_id
    "zbmath"
  end

  def get_records(options = {})
    client = OAI::Client.new "https://oai.portal.mardi4nfdi.de/oai/OAIHandler"
    count = 0
    begin
      # If option to write to file is set, open the file
      if options[:filename]
        out_file = File.open(options[:filename], "w")
      end

      # Using the .full.each pattern allows transparent handling of the resumption token pattern in the OAI protocol
      # rather than having to deal with it manually. The client should only load one page into memory at a time, so the
      # efficiency should be ok.
      client.list_identifiers(metadata_prefix: "datacite_swmath", from: options[:from],
                              until: options[:until]).full.each do |record|

        # If option to write to file is set, write the record to the file
        if options[:filename]
          out_file.write(record.identifier.to_s + "\n")
        else
        # Otherwise, queue the record for import
          Rails.logger.info "Queueing ZBMath Software record #{record.identifier} for import."
          ZbmathSoftwareImportJob.perform_later(record.identifier)
        end
        count += 1
      end
    rescue OAI::NoMatchException
      Rails.logger.warn "No ZBMath Software records updated between #{options[:from]} and #{options[:until]}."
      return nil
    rescue OAI::Exception => e
      if e.message.include?("Gateway Timeout")
        Rails.logger.warn "Got Gateway Timeout error from OAI server for ZBMath Software records updated between #{options[:from]} and #{options[:until]}."
        raise RuntimeError("Gateway Timeout")
      else
        raise e
      end
    end
    count
  end

  def get_zbmath_record(identifier)
    client = OAI::Client.new "https://oai.portal.mardi4nfdi.de/oai/OAIHandler"
    begin
      response = client.get_record(identifier: identifier, metadata_prefix: "datacite_swmath")
      response.record
    rescue OAI::IdException
      Rails.logger.warn "ZBMath Software record #{identifier} not found in the OAI server."
      nil
    rescue OAI::Exception => e
      if e.message.include?("Gateway Timeout")
        Rails.logger.warn "Got Gateway Timeout error from OAI server for ZBMath Software record #{identifier}."
        raise RuntimeError("Gateway Timeout")
      else
        raise e
      end
    end
  end

  def self.process_zbmath_record(identifier)
    # Get the record
    z = ZbmathSoftware.new
    record = z.get_zbmath_record(identifier)
    if record.nil?
      Rails.logger.warn "No valid record returned from OAI server for ZBMath Software record #{identifier}."
      return nil
    end

    # Get the metadata - read_datacite expects a string of the XML tree with the <resource> element as the root,
    # and OAI wraps the data in a <metadata> element so strip this with string slicing (a little ugly, but a lot
    # simpler and more efficient than parsing the XML, restructuring the tree and then serializing back to string).
    begin
      meta = read_datacite(string: record.metadata.to_s[10..-12])
    rescue Exception => e
      Rails.logger.error "Error processing ZBMath Software record #{identifier}: #{e.message}"
      raise
    end

    # Get the subject
    # The subject here is the swMATH identifier, and occurring DataCite DOIs will be the objects
    subj_id = Array.wrap(meta.fetch("identifiers", nil)).detect do |r|
      r["identifierType"] == "URL" && r["identifier"].start_with?("https://swmath.org/software")
    end&.fetch("identifier", nil)
    return nil if subj_id.blank?

    # parse out valid related identifiers
    related_doi_identifiers = Array.wrap(meta.fetch("related_identifiers", nil)).select do |r|
      %w(DOI arXiv).include?(r["relatedIdentifierType"])
    end

    # loop through related identifiers and build event objects
    items = Array.wrap(related_doi_identifiers).reduce([]) do |x, item|
      related_identifier = item.fetch("relatedIdentifier", nil).to_s.strip.downcase
      related_identifier_type = item.fetch("relatedIdentifierType", nil).to_s.strip

      if related_identifier_type == "DOI"
        obj_id = normalize_doi(related_identifier)
        # Get RA and populate obj if it's a DataCite DOI
        related_ra = cached_doi_ra(related_identifier)
        obj = if related_ra == "DataCite"
                cached_datacite_response(obj_id)
              else
                {}
              end
      else
        # It's a arXiv ID so convert it to a DOI and get the DataCite metadata
        arxiv_identifier = if related_identifier.downcase.start_with?("arxiv:")
                             "arXiv.#{related_identifier[6..]}"
                           else
                             "arXiv.#{related_identifier}"
                           end
        obj_id = normalize_doi("#{ARXIV_PREFIX}/#{arxiv_identifier}")
        obj = cached_datacite_response(obj_id)
        related_ra = "DataCite"
      end

      # Add DataCite <-> Other events
      if related_ra == "DataCite"
        x << { "message_action" => "create",
               "id" => SecureRandom.uuid,
               "subj_id" => subj_id,
               "obj_id" => obj_id,
               "relation_type_id" => item["relationType"].to_s.underscore,
               "source_id" => "zbmath_related",
               "occurred_at" => Time.zone.now.utc,
               "timestamp" => Time.zone.now.iso8601,
               "license" => LICENSE,
               "subj" => {},
               "obj" => obj,
               "source_token" => ENV["ZBMATH_RELATED_SOURCE_TOKEN"] || "4c891c31-519e-4d98-ac8d-876ad0f28635" }
      end
      x
    end

    # Loop items and send events to the queue
    Array.wrap(items).each do |item|
      if item["subj_id"].present? && item["relation_type_id"].present? && item["obj_id"].present?
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
      else
        Rails.logger.warn("ZBMath Software record #{identifier} generated an invalid event: #{item}")
      end
    end
    items.length
  end
end
