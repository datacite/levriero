module Importable
  extend ActiveSupport::Concern

  included do
    # strong_parameters throws an error, using attributes hash
    def update_record(attributes)
      logger = Logger.new(STDOUT)

      if update_attributes(attributes)
        logger.debug self.class.name + " " + id + " updated."
      else
        logger.info self.class.name + " " + id + " not updated: " + errors.to_a.inspect
      end
    end

    def delete_record
      logger = Logger.new(STDOUT)

      if destroy(refresh: true)
        logger.debug self.class.name + " record deleted."
      else
        logger.info self.class.name + " record not deleted: " + errors.to_a.inspect
      end
    end
  end

  module ClassMethods
    def get_doi_ra(prefix)
      return nil if prefix.blank?
  
      url = "https://doi.org/ra/#{prefix}"
      result = Maremma.get(url)
  
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?
  
      result.body.dig('data', 0, 'RA')
    end
  
    def validate_doi(doi)
      Array(/\A(?:(http|https):\/\/(dx\.)?doi.org\/)?(doi:)?(10\.\d{4,5}\/.+)\z/.match(doi)).last
    end
  
    def validate_prefix(doi)
      Array(/\A(?:(http|https):\/\/(dx\.)?doi.org\/)?(doi:)?(10\.\d{4,5})\/.+\z/.match(doi)).last
    end
  
    def normalize_doi(doi)
      doi = validate_doi(doi)
      return nil unless doi.present?
  
      # remove non-printing whitespace and downcase
      doi = doi.delete("\u200B").downcase
  
      # turn DOI into URL, escape unsafe characters
      "https://doi.org/" + Addressable::URI.encode(doi)
    end

    def normalize_url(id)
      return nil unless id.present?

      # check for valid protocol. We support AWS S3 and Google Cloud Storage
      uri = Addressable::URI.parse(id)
      return nil unless uri && uri.host && %w(http https ftp s3 gs).include?(uri.scheme)

      # clean up URL
      uri = PostRank::URI.clean(id)
    rescue Addressable::URI::InvalidURIError
      nil
    end
  
    def orcid_from_url(url)
      Array(/\A(http|https):\/\/orcid\.org\/(.+)/.match(url)).last
    end
  
    def orcid_as_url(orcid)
      "http://orcid.org/#{orcid}" if orcid.present?
    end
  
    def validate_orcid(orcid)
      orcid = Array(/\A(?:(http|https):\/\/(www\.)?orcid\.org\/)?(\d{4}[[:space:]-]\d{4}[[:space:]-]\d{4}[[:space:]-]\d{3}[0-9X]+)\z/.match(orcid)).last
      orcid.gsub(/[[:space:]]/, "-") if orcid.present?
    end

    def normalize_orcid(orcid)
      orcid = validate_orcid(orcid)
      return nil unless orcid.present?

      # turn ORCID ID into URL
      "http://orcid.org/" + Addressable::URI.encode(orcid)
    end

    def import_from_api
      logger = Logger.new(STDOUT)

      route = self.name.downcase + "s"
      page_number = 1
      total_pages = 1
      total = 0

      # paginate through API results
      while page_number <= total_pages
        params = { "page[number]" => page_number, "page[size]" => 100 }.compact
        url = ENV['API_URL'] + "/#{route}?" + URI.encode_www_form(params)

        response = Maremma.get(url, content_type: 'application/vnd.api+json')
        logger.warn response.body["errors"].inspect if response.body.fetch("errors", nil).present?

        records = response.body.fetch("data", [])
        records.each do |data|
          if self.name == "Client"
            provider_id = data.dig("relationships", "provider", "data", "id")
            data["attributes"]["provider_id"] = provider_id
          end

          ImportJob.perform_later(data.except("relationships"))
        end

        processed = (page_number - 1) * 100 + records.size
        logger.info "#{processed} " + self.name.downcase + "s processed."

        page_number = response.body.dig("meta", "page").to_i + 1
        total = response.body.dig("meta", "total") || total
        total_pages = response.body.dig("meta", "total-pages") || 0
      end

      total
    end

    def parse_record(sqs_msg: nil, data: nil)
      logger = Logger.new(STDOUT)

      id = "https://doi.org/#{data["id"]}"
      response = get_datacite_json(id)
      related_identifiers = Array.wrap(response.fetch("relatedIdentifiers", nil)).select { |r| ["DOI", "URL"].include?(r["relatedIdentifierType"]) }
       
      if related_identifiers.any? { |r| r["relatedIdentifierType"] == "DOI" }
        item = {
          "id" => data["id"],
          "type" => "dois",
          "attributes" => response
        }
        RelatedIdentifier.push_item(item)
      end

      if related_identifiers.any? { |r| r["relatedIdentifierType"] == "URL" }
        item = {
          "id" => data["id"],
          "type" => "dois",
          "attributes" => response
        }
        RelatedUrl.push_item(item)
      end

      funding_references = Array.wrap(response.fetch("fundingReferences", nil)).select { |f| f.fetch("funderIdentifierType", nil) == "Crossref Funder ID" }
      if funding_references.present?
        item = {
          "doi" => data["id"],
          "type" => "dois",
          "attributes" => response
        }
        FunderIdentifier.push_item(item)
      end 

      name_identifiers = Array.wrap(response.fetch("creators", nil)).select { |n| Array.wrap(n.fetch("nameIdentifiers", nil)).any? { |n| n["nameIdentifierScheme"] == "ORCID" } }
      if name_identifiers.present?
        item = {
          "doi" => data["id"],
          "type" => "dois",
          "attributes" => response
        }
        NameIdentifier.push_item(item)
      end

      logger.info "[Event Data] #{related_identifiers.length} related_identifiers found for DOI #{data["id"]}" if related_identifiers.present?
      logger.info "[Event Data] #{name_identifiers.length} name_identifiers found for DOI #{data["id"]}" if name_identifiers.present?
      logger.info "[Event Data] #{funding_references.length} funding_references found for DOI #{data["id"]}" if funding_references.present?
      logger.info "No events found for DOI #{data["id"]}" if related_identifiers.blank? && name_identifiers.blank? && funding_references.blank?

      related_identifiers + name_identifiers + funding_references
    end

    def create_record(attributes)
      parameters = ActionController::Parameters.new(attributes)
      self.new(parameters.permit(self.safe_params))
    end

    def to_kebab_case(hsh)
      hsh.stringify_keys.transform_keys!(&:underscore)
    end
  end
end
