class OrcidUpdate < Base
  def source_id
    "orcid_update"
  end

  def query
    "nameIdentifier:ORCID\\:*"
  end

  def parse_data(result, options={})
    return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

    items = result.body.fetch("data", {}).fetch('response', {}).fetch('docs', nil)
    claim_action = options[:claim_action].presence || "create"

    Array(items).reduce([]) do |sum, item|
      doi = item.fetch("doi")
      related_identifiers = item.fetch("relatedIdentifier", [])
      skip_doi = related_identifiers.any? do |related_identifier|
        ["IsIdenticalTo", "IsPartOf", "IsPreviousVersionOf"].include?(related_identifier.split(':', 3).first)
      end
      name_identifiers = item.fetch("nameIdentifier", [])

      if name_identifiers.blank? || (skip_doi && claim_action == "create") || (!skip_doi && claim_action == "delete")
        sum
      else
        name_identifiers.each do |name_identifier|
          orcid = name_identifier.split(':', 2).last
          orcid = validate_orcid(orcid)

          next if orcid.blank?

          sum << { "orcid" => orcid,
                    "doi" => doi,
                    "source_id" => source_id,
                    "claim_action"=> claim_action }
        end
        sum
      end
    end
  end

  def push_item(item, options={})
    if options[:access_token].blank?
      puts "Access token missing."
      return 1
    end

    host = options[:push_url].presence || "https://profiles.datacite.org/api"
    push_url = host + "/claims"

    response = Maremma.post(push_url, data: { "claim" => item }.to_json,
                                      bearer: options[:access_token],
                                      content_type: 'json')
    if response.body["data"].present?
      doi = response.body.fetch("data", {}).fetch("attributes", {}).fetch("doi", nil)
      orcid = response.body.fetch("data", {}).fetch("attributes", {}).fetch("orcid", nil)
      claim_action = response.body.fetch("data", {}).fetch("attributes", {}).fetch("claim-action", nil)
      puts "#{claim_action.titleize} DOI #{doi} for ORCID ID #{orcid} pushed to Profiles service."
      0
    elsif response.body["errors"].present?
      claim_action = options[:claim_action].presence || "create"
      
      puts "#{claim_action.titleize} DOI #{doi} for ORCID ID #{orcid} had an error:"
      puts "#{response.body['errors'].first['title']}"
      1
    end
  end
end