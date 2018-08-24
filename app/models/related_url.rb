class RelatedUrl < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"

  def self.import_by_month(options={})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select {|d| d.day == 1}.each do |m|
      RelatedUrlImportByMonthJob.perform_later(from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for DOIs updated from #{from_date.strftime("%F")} until #{until_date.strftime("%F")}."
  end

  def self.import(options={})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    related_url = RelatedUrl.new
    related_url.queue_jobs(related_url.unfreeze(from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F")))
  end

  def source_id
    "datacite_url"
  end

  def query
    "relatedIdentifier:URL\\:*"
  end

  def push_data(result, options={})
    return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

    items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)
    # Rails.logger.info "Extracting related urls for #{items.size} DOIs updated from #{options[:from_date]} until #{options[:until_date]}."

    Array.wrap(items).map do |item|
      RelatedUrlImportJob.perform_later(item)
    end

    items.length
  end

  def self.push_item(item)
    doi = item.fetch("doi")
    pid = normalize_doi(doi)
    related_urls = item.fetch('relatedIdentifier', []).select { |id| id =~ /:URL:.+/ }

    push_items = Array.wrap(related_urls).reduce([]) do |ssum, iitem|
      raw_relation_type, _related_identifier_type, related_url = iitem.split(':', 3)
      related_url = related_url.strip.downcase

      obj_id = normalize_url(related_url)
      source_id = "datacite_url"
      source_token = ENV['DATACITE_URL_SOURCE_TOKEN']

      # only create event if valid http/https/ftp URL
      if obj_id.present?
        subj = cached_datacite_response(pid)

        ssum << { "id" => SecureRandom.uuid,
                  "message_action" => "create",
                  "subj_id" => pid,
                  "obj_id" => obj_id,
                  "relation_type_id" => raw_relation_type.underscore,
                  "source_id" => source_id,
                  "source_token" => source_token,
                  "occurred_at" => item.fetch("updated"),
                  "license" => LICENSE,
                  "subj" => subj,
                  "obj" => {} }
      end
      
      ssum
    end

    # there can be one or more related_url per DOI
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
              "relation-type-id" => iiitem["relation_type_id"].to_s.dasherize,
              "source-id" => iiitem["source_id"].to_s.dasherize,
              "source-token" => iiitem["source_token"],
              "occurred-at" => iiitem["occurred_at"],
              "license" => iiitem["license"],
              "subj" => iiitem["subj"],
              "obj" => iiitem["obj"] } }}

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
    end
  end
end
