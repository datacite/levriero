module Importable
  extend ActiveSupport::Concern

  included do
    # strong_parameters throws an error, using attributes hash
    def update_record(attributes)
      if update(attributes)
        Rails.logger.debug "#{self.class.name} #{id} updated."
      else
        Rails.logger.error "#{self.class.name} #{id} not updated: #{errors.to_a.inspect}"
      end
    end

    def delete_record
      if destroy(refresh: true)
        Rails.logger.debug "#{self.class.name} record deleted."
      else
        Rails.logger.error "#{self.class.name} record not deleted: #{errors.to_a.inspect}"
      end
    end
  end

  module ClassMethods
    def get_doi_ra(prefix)
      return nil if prefix.blank?

      url = "https://doi.org/ra/#{prefix}"
      result = Maremma.get(url)

      return result.body.fetch("errors") if result.body.fetch("errors",
                                                              nil).present?

      result.body.dig("data", 0, "RA")
    end

    def validate_doi(doi)
      Array(/\A(?:(http|https):\/\/(dx\.)?doi.org\/)?(doi:)?(10\.\d{4,5}\/.+)\z/.match(doi)).last
    end

    def validate_prefix(doi)
      Array(/\A(?:(http|https):\/\/(dx\.)?doi.org\/)?(doi:)?(10\.\d{4,5})\/.+\z/.match(doi)).last
    end

    def normalize_doi(doi)
      doi = validate_doi(doi)
      return nil if doi.blank?

      # remove non-printing whitespace and downcase
      doi = doi.delete("\u200B").downcase

      # turn DOI into URL, escape unsafe characters
      "https://doi.org/#{Addressable::URI.encode(doi)}"
    end

    def normalize_url(id)
      return nil if id.blank?

      # check for valid protocol. We support AWS S3 and Google Cloud Storage
      uri = Addressable::URI.parse(id)
      return nil unless uri&.host && %w(http https ftp s3
                                        gs).include?(uri.scheme)

      # clean up URL
      PostRank::URI.clean(id)
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def normalize_arxiv(id)
      return nil if id.blank?

      id = id.downcase

      # turn arXiv into a URL if needed
      id = "https://arxiv.org/abs/#{id[6..]}" if id.start_with?("arxiv:")

      # check for valid protocol.
      uri = Addressable::URI.parse(id)
      return nil unless uri&.host && %w(http https).include?(uri.scheme)

      # clean up URL
      PostRank::URI.clean(id)
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def normalize_igsn(id)
      return nil if id.blank?

      id = id.downcase

      # turn igsn into a URL if needed
      id = "https://hdl.handle.net/10273/#{id}" unless id.start_with?("http")

      # check for valid protocol.
      uri = Addressable::URI.parse(id)
      return nil unless uri&.host && %w(http https).include?(uri.scheme)

      # don't use IGSN resolver as no support for ssl
      id = "https://hdl.handle.net/10273/#{id[15..]}" if id.start_with?("http://igsn.org")

      # clean up URL
      PostRank::URI.clean(id.downcase)
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def normalize_handle(id)
      return nil if id.blank?

      id = id.downcase

      # turn handle into a URL if needed
      id = "https://hdl.handle.net/#{id}" unless id.start_with?("http")

      # check for valid protocol.
      uri = Addressable::URI.parse(id)
      return nil unless uri&.host && %w(http https).include?(uri.scheme)

      # clean up URL
      PostRank::URI.clean(id.downcase)
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def normalize_pmid(id)
      return nil if id.blank?

      id = id.downcase

      # strip pmid prefix
      id = id[5..] if id.start_with?("pmid:")

      # turn handle into a URL if needed
      id = "https://identifiers.org/pubmed:#{id}" unless id.start_with?("http")

      # check for valid protocol.
      uri = Addressable::URI.parse(id)
      return nil unless uri&.host && %w(http https).include?(uri.scheme)

      # clean up URL
      PostRank::URI.clean(id.downcase)
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def orcid_from_url(url)
      Array(/\A(http|https):\/\/orcid\.org\/(.+)/.match(url)).last
    end

    def orcid_as_url(orcid)
      "https://orcid.org/#{orcid}" if orcid.present?
    end

    def validate_orcid(orcid)
      orcid = Array(/\A(?:(http|https):\/\/(www\.)?orcid\.org\/)?(\d{4}[[:space:]-]\d{4}[[:space:]-]\d{4}[[:space:]-]\d{3}[0-9X]+)\z/.match(orcid)).last
      orcid.gsub(/[[:space:]]/, "-") if orcid.present?
    end

    def normalize_orcid(orcid)
      orcid = validate_orcid(orcid)
      return nil if orcid.blank?

      # turn ORCID ID into URL
      "https://orcid.org/#{Addressable::URI.encode(orcid)}"
    end

    def validate_ror(ror_id)
      Array(/\A(?:(http|https):\/\/)?(ror\.org\/0\w{6}\d{2})\z/.match(ror_id)).last
    end

    def normalize_ror(ror_id)
      ror_id = validate_ror(ror_id)
      return nil if ror_id.blank?

      # turn ROR ID into URL
      "https://#{Addressable::URI.encode(ror_id)}"
    end

    def import_from_api
      route = "#{name.downcase}s"
      page_number = 1
      total_pages = 1
      total = 0

      # paginate through API results
      while page_number <= total_pages
        params = { "page[number]" => page_number, "page[size]" => 100 }.compact
        url = ENV["API_URL"] + "/#{route}?" + URI.encode_www_form(params)

        response = Maremma.get(url, content_type: "application/vnd.api+json")
        Rails.logger.error response.body["errors"].inspect if response.body.fetch(
          "errors", nil
        ).present?

        records = response.body.fetch("data", [])
        records.each do |data|
          if name == "Client"
            provider_id = data.dig("relationships", "provider", "data", "id")
            data["attributes"]["provider_id"] = provider_id
          end

          ImportJob.perform_later(data.except("relationships"))
        end

        processed = (page_number - 1) * 100 + records.size
        Rails.logger.info "#{processed} #{name.downcase}s processed."

        page_number = response.body.dig("meta", "page").to_i + 1
        total = response.body.dig("meta", "total") || total
        total_pages = response.body.dig("meta", "total-pages") || 0
      end

      total
    end

    def parse_record(sqs_msg: nil, data: nil)
      id = "https://doi.org/#{data['id']}"
      response = get_datacite_json(id)

      related_identifiers = Array.wrap(
        response.fetch("relatedIdentifiers", nil)).select do |r|
          ["DOI", "URL"].include?(r["relatedIdentifierType"])
      end

      if related_identifiers.any? { |r| r["relatedIdentifierType"] == "DOI" }
        item = {
          "id" => data["id"],
          "type" => "dois",
          "attributes" => response,
        }
        RelatedIdentifier.push_item(item)
      end

      if related_identifiers.any? { |r| r["relatedIdentifierType"] == "URL" }
        item = {
          "id" => data["id"],
          "type" => "dois",
          "attributes" => response,
        }
        RelatedUrl.push_item(item)
      end

      funding_references = Array.wrap(response.fetch("fundingReferences",
                                                     nil)).select do |f|
        f.fetch("funderIdentifierType", nil) == "Crossref Funder ID"
      end

      if funding_references.present?
        item = {
          "doi" => data["id"],
          "type" => "dois",
          "attributes" => response,
        }
        FunderIdentifier.push_item(item)
      end

      name_identifiers = Array.wrap(response.fetch("creators",
                                                   nil)).select do |n|
        Array.wrap(n.fetch("nameIdentifiers",
                           nil)).any? do |n|
          n["nameIdentifierScheme"] == "ORCID"
        end
      end
      if name_identifiers.present?
        item = {
          "doi" => data["id"],
          "type" => "dois",
          "attributes" => response,
        }
        # NameIdentifier.push_item(item)
      end

      affiliation_identifiers = Array.wrap(response.fetch("creators",
                                                          nil)).select do |n|
        Array.wrap(n.fetch("affiliation",
                           nil)).any? do |n|
          n["affiliationIdentifierScheme"] == "ROR"
        end && Array.wrap(n.fetch(
                            "nameIdentifiers", nil
                          )).any? do |n|
                 n["nameIdentifierScheme"] == "ORCID"
               end
      end
      if affiliation_identifiers.present?
        item = {
          "doi" => data["id"],
          "type" => "dois",
          "attributes" => response,
        }
        # AffiliationIdentifier.push_item(item)
      end

      orcid_affiliation = Array.wrap(response.fetch("creators",
                                                    nil)).select do |n|
        Array.wrap(n.fetch("affiliation", nil)).any? do |n|
          n["affiliationIdentifierScheme"] == "ROR"
        end
      end
      if orcid_affiliation.present?
        item = {
          "doi" => data["id"],
          "type" => "dois",
          "attributes" => response,
        }
        # OrcidAffiliation.push_item(item)
      end

      related_identifiers + name_identifiers + funding_references + affiliation_identifiers + orcid_affiliation
    end

    def create_record(attributes)
      parameters = ActionController::Parameters.new(attributes)
      new(parameters.permit(safe_params))
    end

    def to_kebab_case(hsh)
      hsh.stringify_keys.transform_keys!(&:underscore)
    end
  end
end
