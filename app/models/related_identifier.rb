class RelatedIdentifier < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"

  def source_id
    "datacite_related"
  end

  def query
    "relatedIdentifier:DOI\\:*"
  end

  def parse_data(result, options={})
    return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

    items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)
    registration_agencies = {}

    Array.wrap(items).reduce([]) do |sum, item|
      doi = item.fetch("doi")
      pid = normalize_doi(doi)
      related_doi_identifiers = item.fetch('relatedIdentifier', []).select { |id| id =~ /:DOI:.+/ }

      # don't generate event if there is a DOI for identical content with same prefix
      skip_doi = related_doi_identifiers.any? do |related_identifier|
        ["IsIdenticalTo"].include?(related_identifier.split(':', 3).first) &&
        related_identifier.split(':', 3).last.to_s.starts_with?(validate_prefix(doi))
      end

      unless skip_doi
        sum += Array(related_doi_identifiers).reduce([]) do |ssum, iitem|
          raw_relation_type, _related_identifier_type, related_identifier = iitem.split(':', 3)
          related_identifier = related_identifier.strip.downcase
          prefix = validate_prefix(related_identifier)
          registration_agencies[prefix] = get_doi_ra(prefix) unless registration_agencies[prefix]

          # check whether this is a DataCite DOI
          if %w(Crossref).include?(registration_agencies[prefix])
            ssum << { "id" => SecureRandom.uuid,
                      "message_action" => "create",
                      "subj_id" => pid,
                      "obj_id" => normalize_doi(related_identifier),
                      "relation_type_id" => raw_relation_type.underscore,
                      "source_id" => "datacite",
                      "source_token" => options[:source_token],
                      "occurred_at" => item.fetch("updated"),
                      "license" => LICENSE }
          else
            ssum
          end
        end
      end

      sum
    end
  end

  def push_item(item, options={})
    if options[:access_token].blank?
      puts "Access token missing."
      return 1
    end

    host = options[:push_url].presence || "https://bus.eventdata.crossref.org"
    push_url = host + "/events"

    if options[:jsonapi]
      data = { "data" => {
                  "id" => item["id"],
                  "type" => "events",
                  "attributes" => {
                    "message-action" => item["message_action"],
                    "subj-id" => item["subj_id"],
                    "obj-id" => item["obj_id"],
                    "relation-type-id" => item["relation_type_id"],
                    "source-id" => "datacite-crossref",
                    "source-token" => item["source_token"],
                    "occurred-at" => item["occurred_at"],
                    "license" => item["license"] } }}

      response = Maremma.post(push_url, data: data.to_json,
                                        bearer: options[:access_token],
                                        content_type: 'json',
                                        host: host)
    else
      response = Maremma.post(push_url, data: item.to_json,
                                        bearer: options[:access_token],
                                        content_type: 'json',
                                        host: host)
    end

    # return 0 if successful, 1 if error
    if response.status == 201
      puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} pushed to Event Data service."
      0
    elsif response.status == 409
      puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} already pushed to Event Data service."
      0
    elsif response.body["errors"].present?
      puts "#{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} had an error:"
      puts "#{response.body['errors'].first['title']}"
      1
    end
  end
end
