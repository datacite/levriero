class NameIdentifier < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/".freeze

  include Queueable

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      NameIdentifierImportByMonthJob.perform_later(from_date: m.strftime("%F"),
                                                   until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for DOIs created from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    name_identifier = NameIdentifier.new
    name_identifier.queue_jobs(name_identifier.unfreeze(from_date: from_date.strftime("%F"),
                                                        until_date: until_date.strftime("%F")))
  end

  def self.import_one(options = {})
    doi = options[:doi]

    if doi.blank?
      message = "Error DOI #{doi}: not provided"
      Rails.logger.error message
      return message
    end

    attributes = get_datacite_json(doi)
    response = push_item({ "id" => doi, "type" => "dois",
                           "attributes" => attributes })
  end

  def source_id
    "datacite_orcid_auto_update"
  end

  def query
    "creators.nameIdentifiers.nameIdentifierScheme:ORCID"
  end

  def push_data(result, _options = {})
    return result.body.fetch("errors") if result.body.fetch("errors",
                                                            nil).present?

    items = result.body.fetch("data", [])

    Array.wrap(items).map do |item|
      NameIdentifierImportJob.perform_later(item)
    rescue Aws::SQS::Errors::InvalidParameterValue, Aws::SQS::Errors::RequestEntityTooLarge,
           Seahorse::Client::NetworkingError => e
      Rails.logger.error e.message
    end

    items.length
  end

  def self.push_item(item)
    attributes = item.fetch("attributes", {})
    doi = attributes.fetch("doi", nil)
    return nil if doi.blank?

    pid = normalize_doi(doi)
    related_identifiers = Array.wrap(attributes.fetch("relatedIdentifiers",
                                                      nil))

    raid_registry_record = raid_registry_record?(attributes)

    ## Don't process DOIs with certain relationTypes or DOIs in a raidRegistry
    skip_doi = related_identifiers.any? do |related_identifier|
      ["IsPartOf"].include?(related_identifier["relationType"] || "")
    end || raid_registry_record

    creators = attributes.fetch("creators", []).select do |n|
      Array.wrap(n.fetch("nameIdentifiers", nil)).any? do |n|
        n["nameIdentifierScheme"] == "ORCID"
      end
    end
    return nil if creators.blank? || skip_doi

    source_id = item.fetch("sourceId", "datacite_orcid_auto_update")

    push_items = Array.wrap(creators).reduce([]) do |ssum, iitem|
      name_identifier = Array.wrap(iitem.fetch("nameIdentifiers",
                                               nil)).detect do |n|
        n["nameIdentifierScheme"] == "ORCID"
      end
      obj_id = normalize_orcid(name_identifier["nameIdentifier"]) if name_identifier.present?

      if name_identifier.present? && obj_id.present?
        ssum << { "subj_id" => pid,
                  "obj_id" => obj_id,
                  "source_id" => source_id }
      end

      ssum
    end

    # there can be one or more name_identifier per DOI
    Array.wrap(push_items).each do |iiitem|
      # send to Profiles service, which then pushes to ORCID
      if ENV["STAFF_PROFILES_ADMIN_TOKEN"].present?
        push_url = "#{ENV['VOLPINO_URL']}/claims"
        doi = doi_from_url(iiitem["subj_id"])

        # Capture the prefix
        prefix = validate_prefix(doi)
        # Check prefix against known exclusions
        if !ENV["EXCLUDE_PREFIXES_FROM_ORCID_CLAIMING"].to_s.split(",").include?(prefix)

          orcid = orcid_from_url(iiitem["obj_id"])
          source_id = iiitem["source_id"] == "datacite_orcid_auto_update" ? "orcid_update" : "orcid_search"

          data = {
            "claim" => {
              "doi" => doi,
              "orcid" => orcid,
              "source_id" => source_id,
              "claim_action" => "create",
            },
          }

          response = Maremma.post(push_url, data: data.to_json,
                                            bearer: ENV["STAFF_PROFILES_ADMIN_TOKEN"],
                                            content_type: "application/json")

          if response.status == 202
            Rails.logger.info "[Profiles] claim ORCID ID #{orcid} for DOI #{doi} pushed to Profiles service."
          elsif response.status == 409
            Rails.logger.info "[Profiles] claim ORCID ID #{orcid} for DOI #{doi} already pushed to Profiles service."
          elsif response.body["errors"].present?
            Rails.logger.error "[Profiles] claim ORCID ID #{orcid} for DOI #{doi} had an error: #{response.body['errors']}"
          end
        end
      end
    end

    push_items.length
  end
end
