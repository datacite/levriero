module Importable
  extend ActiveSupport::Concern

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

        response.body.fetch("data", []).each do |record|
          id = record.fetch("id", nil)
          params = record.fetch("attributes", {})
            .except("has-password")
            .transform_keys! { |key| key.tr('-', '_') }

          if self.name == "Client"
            provider_id = record.dig("relationships", "provider", "data", "id")
            params = params.merge("provider_id" => provider_id)
          end

          parameters = ActionController::Parameters.new(params)
          result = find_by_id(id)

          if result.present?
            # strong_parameters throws an error
            result.update_attributes(params)

            if result.valid?
              Rails.logger.info self.name + " " + id + " updated."
            else
              Rails.logger.info self.name + " " + id + " not updated: " + result.errors.messages.values.first.first
            end
          else
            result = self.create(parameters.permit(self.safe_params))

            if result.valid?
              Rails.logger.info self.name + " " + id + " created."
            else
              Rails.logger.info self.name + " " + id + " not created: " + result.errors.messages.values.first.first
            end
          end
        end

        page_number = response.body.dig("meta", "page").to_i + 1
        total = response.body.dig("meta", "total") || total
        total_pages = response.body.dig("meta", "total-pages") || 0
      end

      total
    end

    def to_kebab_case(hsh)
      hsh.stringify_keys.transform_keys! { |key| key.tr('-', '_') }
    end
  end
end
