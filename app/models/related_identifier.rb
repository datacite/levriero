class RelatedIdentifier < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"

  def self.import_by_month(options={})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select {|d| d.day == 1}.each do |m|
      RelatedIdentifierImportByMonthJob.perform_later(from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for DOIs updated from #{from_date.strftime("%F")} until #{until_date.strftime("%F")}."
  end

  def self.import(options={})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    related_identifier = RelatedIdentifier.new
    related_identifier.queue_jobs(related_identifier.unfreeze(from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F")))
  end

  def source_id
    "datacite_related"
  end

  def query
    "relatedIdentifier:DOI\\:*"
  end

  def push_data(result, options={})
    return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

    items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)

    Array.wrap(items).map do |item|
      RelatedIdentifierImportJob.perform_later(item)
    end

    items.length
  end

  def self.push_item(item)
    doi = item.fetch("doi")
    pid = normalize_doi(doi)
    related_doi_identifiers = item.fetch('relatedIdentifier', []).select { |id| id =~ /:DOI:.+/ }
    registration_agencies = {}

    push_items = Array.wrap(related_doi_identifiers).reduce([]) do |ssum, iitem|
      raw_relation_type, _related_identifier_type, related_identifier = iitem.split(':', 3)
      related_identifier = related_identifier.strip.downcase
      prefix = validate_prefix(related_identifier)
      registration_agencies[prefix] = get_doi_ra(prefix) unless registration_agencies[prefix]
      if registration_agencies[prefix] == "DataCite"
        source_id = "datacite_related"
        source_token = ENV['DATACITE_RELATED_SOURCE_TOKEN']
      elsif registration_agencies[prefix] == "Crossref"
        source_id = "datacite_crossref"
        source_token = ENV['DATACITE_CROSSREF_SOURCE_TOKEN']
      else
        source_id = "datacite_other"
        source_token = ENV['DATACITE_OTHER_SOURCE_TOKEN']
      end

      ssum << { "id" => SecureRandom.uuid,
                "message_action" => "create",
                "subj_id" => pid,
                "obj_id" => normalize_doi(related_identifier),
                "relation_type_id" => raw_relation_type.underscore,
                "source_id" => source_id,
                "source_token" => source_token,
                "occurred_at" => item.fetch("updated"),
                "license" => LICENSE }
    end

    # there can be one or more related_identifier per DOI
    Array.wrap(push_items).each do |iiitem|
      # send to DataCite Event Data Query API
      if ENV['LAGOTTINO_TOKEN'].present?
        push_url = ENV['LAGOTTINO_URL'] + "/events"

        data = { 
          "data" => {
            "id" => iiitem["id"],
            "type" => "events",
            "attributes" => {
              "message-action" => iiitem["message_action"],
              "subj-id" => iiitem["subj_id"],
              "obj-id" => iiitem["obj_id"],
              "relation-type-id" => iiitem["relation_type_id"],
              "source-id" => iiitem["source_id"],
              "source-token" => iiitem["source_token"],
              "occurred-at" => iiitem["occurred_at"],
              "license" => iiitem["license"] } }}

        response = Maremma.post(push_url, data: data.to_json,
                                          bearer: ENV['LAGOTTINO_TOKEN'],
                                          content_type: 'json')

        if response.status == 201
          Rails.logger.info "#{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} pushed to Event Data service."
        elsif response.status == 409
          Rails.logger.info "#{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} already pushed to Event Data service."
        elsif response.body["errors"].present?
          Rails.logger.info "#{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} had an error: #{response.body['errors'].first['title']}"
        end
      end
      
      # send to Event Data Bus
      # host = ENV['EVENTDATA_URL']
      # push_url = host + "/events"
      # response = Maremma.post(push_url, data: item.to_json,
      #                                   bearer: ENV['EVENTDATA_TOKEN'],
      #                                   content_type: 'json',
      #                                   host: host)

      # return 0 if successful, 1 if error
      # if response.status == 201
      #   puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} pushed to Event Data service."
      #   0
      # elsif response.status == 409
      #   puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} already pushed to Event Data service."
      #   0
      # elsif response.body["errors"].present?
      #   puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} had an error:"
      #   puts "#{response.body['errors'].first['title']}"
      #   1
      # end
    end
  end
end
