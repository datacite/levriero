class NameIdentifier < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"

  def self.import_by_month(options={})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select {|d| d.day == 1}.each do |m|
      NameIdentifierImportByMonthJob.perform_later(from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for DOIs created from #{from_date.strftime("%F")} until #{until_date.strftime("%F")}."
  end

  def self.import(options={})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    name_identifier = NameIdentifier.new
    name_identifier.queue_jobs(name_identifier.unfreeze(from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F")))
  end

  def source_id
    "datacite_orcid_auto_update"
  end

  def query
    "nameIdentifier:ORCID\\:*"
  end

  def push_data(result, options={})
    logger = Logger.new(STDOUT)
    return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

    items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)

    Array.wrap(items).map do |item|
      NameIdentifierImportJob.perform_later(item)
    end

    items.length
  end

  def self.push_item(item)
    logger = Logger.new(STDOUT)

    doi = item.fetch("doi")
    pid = normalize_doi(doi)
    related_identifiers = item.fetch("relatedIdentifier", [])
    skip_doi = related_identifiers.any? do |related_identifier|
      ["IsIdenticalTo", "IsPartOf", "IsPreviousVersionOf"].include?(related_identifier.split(':', 3).first)
    end
    name_identifiers = item.fetch("nameIdentifier", [])

    return nil if name_identifiers.blank? || skip_doi

    push_items = Array.wrap(name_identifiers).reduce([]) do |ssum, iitem|
      name_identifier_scheme, name_identifier = iitem.split(':', 2)
      name_identifier = name_identifier.strip
      obj_id = normalize_orcid(name_identifier)
      relation_type_id = "is_authored_by"
      source_id = "datacite_orcid_auto_update"
      source_token = ENV['DATACITE_ORCID_AUTO_UPDATE_SOURCE_TOKEN']

      if obj_id.present?
        subj = cached_datacite_response(pid)
        obj = cached_orcid_response(obj_id)

        ssum << { "message_action" => "create",
                  "subj_id" => pid,
                  "obj_id" => obj_id,
                  "relation_type_id" => relation_type_id,
                  "source_id" => source_id,
                  "source_token" => source_token,
                  "occurred_at" => item.fetch("updated"),
                  "timestamp" => Time.zone.now.iso8601,
                  "license" => LICENSE,
                  "subj" => subj,
                  "obj" => obj }
      end
      
      ssum
    end

    # there can be one or more name_identifier per DOI
    Array.wrap(push_items).each do |iiitem|
      # send to DataCite Event Data Query API
      if ENV['LAGOTTINO_TOKEN'].present?
        push_url = ENV['LAGOTTINO_URL'] + "/events"

        data = { 
          "data" => {
            "type" => "events",
            "attributes" => {
              "message-action" => iiitem["message_action"],
              "subj-id" => iiitem["subj_id"],
              "obj-id" => iiitem["obj_id"],
              "relation-type-id" => iiitem["relation_type_id"].to_s.dasherize,
              "source-id" => iiitem["source_id"].to_s.dasherize,
              "source-token" => iiitem["source_token"],
              "occurred-at" => iiitem["occurred_at"],
              "timestamp" => iiitem["timestamp"],
              "license" => iiitem["license"],
              "subj" => iiitem["subj"],
              "obj" => iiitem["obj"] } }}

        response = Maremma.post(push_url, data: data.to_json,
                                          bearer: ENV['LAGOTTINO_TOKEN'],
                                          content_type: 'application/vnd.api+json')

        if [200, 201].include?(response.status)
          logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} pushed to Event Data service."
        elsif response.status == 409
          logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} already pushed to Event Data service."
        elsif response.body["errors"].present?
          logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} had an error: #{response.body['errors'].first['title']}"
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
