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
          params = record.fetch("attributes", {}).except("has-password").transform_keys! { |key| key.tr('-', '_') }
          parameters = ActionController::Parameters.new(params.merge(id: record.fetch("id")))
          record = self.create(parameters.permit(self.safe_params))

          Rails.logger.info record.errors.inspect unless record.valid?
        end

        page_number = response.body.dig("meta", "page").to_i + 1
        total = response.body.dig("meta", "total") || total
        total_pages = response.body.dig("meta", "total-pages") || 0
      end

      total
    end
  end
end
