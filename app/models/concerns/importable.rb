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
    def import_from_api
      route = self.name.downcase + "s"
      page_number = 1
      total_pages = 1
      total = 0

      # paginate through API results
      while page_number <= total_pages
        params = { "page[number]" => page_number, "page[size]" => 1000 }.compact
        url = ENV['APP_URL'] + "/#{route}?" + URI.encode_www_form(params)

        response = Maremma.get(url, content_type: 'application/vnd.api+json')
        records = response.body.fetch("data", [])

        records.each do |data|
          if self.name == "Client"
            provider_id = data.dig("relationships", "provider", "data", "id")
            data["attributes"]["provider_id"] = provider_id
          end

          ImportJob.perform_later(data.except("relationships"))
        end

        Rails.logger.info "#{records.size} " + self.name.downcase + "s processed."

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
      record = self.new(parameters.permit(self.safe_params))

      if record.save
        Rails.logger.debug self.name + " " + record.id + " created."
      else
        Rails.logger.info self.name + " " + record.id + " not created: " + record.errors.to_a.inspect
      end

      record
    end

    def to_kebab_case(hsh)
      hsh.stringify_keys.transform_keys!(&:underscore)
    end
  end
end
