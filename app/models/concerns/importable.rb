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
          params = record.fetch("attributes", {}).except("has-password").transform_keys! { |key| key.tr('-', '_') }
          parameters = ActionController::Parameters.new(params)
          safe_params = parameters.permit(self.safe_params)
          result = find_by_id(id)

          if result.present?
            # result = result.update_attributes(safe_params)
            # Rails.logger.info self.name + " " + id + " updated."
          else
            result = self.create(safe_params)

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
  end
end
