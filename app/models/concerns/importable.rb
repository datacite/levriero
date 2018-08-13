module Importable
  extend ActiveSupport::Concern

  included do
    # strong_parameters throws an error, using attributes hash
    def update_record(attributes)
      if update_attributes(attributes)
        Rails.logger.debug self.class.name + " " + id + " updated."
      else
        Rails.logger.info self.class.name + " " + id + " not updated: " + errors.to_a.inspect
      end
    end

    def delete_record
      if destroy(refresh: true)
        Rails.logger.debug self.class.name + " record deleted."
      else
        Rails.logger.info self.class.name + " record not deleted: " + errors.to_a.inspect
      end
    end
  end

  module ClassMethods
    def get_doi_ra(prefix)
      return nil if prefix.blank?
  
      url = ENV['API_URL'] + "/prefixes/#{prefix}"
      result = Maremma.get(url)
  
      return result.body.fetch("errors") if result.body.fetch("errors", nil).present?
  
      result.body.dig('data', 'attributes', 'registration-agency')
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
  
    def orcid_from_url(url)
      Array(/\Ahttp:\/\/orcid\.org\/(.+)/.match(url)).last
    end
  
    def orcid_as_url(orcid)
      "http://orcid.org/#{orcid}" if orcid.present?
    end
  
    def validate_orcid(orcid)
      Array(/\A(?:http:\/\/orcid\.org\/)?(\d{4}-\d{4}-\d{4}-\d{3}[0-9X]+)\z/.match(orcid)).last
    end
    def import_from_api
      route = self.name.downcase + "s"
      page_number = 1
      total_pages = 1
      total = 0

      # paginate through API results
      while page_number <= total_pages
        params = { "page[number]" => page_number, "page[size]" => 100 }.compact
        url = ENV['APP_URL'] + "/#{route}?" + URI.encode_www_form(params)

        response = Maremma.get(url, content_type: 'application/vnd.api+json')
        Rails.logger.warn response.body["errors"].inspect if response.body.fetch("errors", nil).present?

        records = response.body.fetch("data", [])
        records.each do |data|
          if self.name == "Client"
            provider_id = data.dig("relationships", "provider", "data", "id")
            data["attributes"]["provider_id"] = provider_id
          end

          ImportJob.perform_later(data.except("relationships"))
        end

        processed = (page_number - 1) * 100 + records.size
        Rails.logger.info "#{processed} " + self.name.downcase + "s processed."

        page_number = response.body.dig("meta", "page").to_i + 1
        total = response.body.dig("meta", "total") || total
        total_pages = response.body.dig("meta", "total-pages") || 0
      end

      total
    end

    def import_record(data)
      attributes = to_kebab_case(data.fetch("attributes").except("has-password"))
      record = find_by_id(data["id"])

      if record.present?
        record.update_record(attributes)
        record
      else
        create_record(attributes)
      end
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
