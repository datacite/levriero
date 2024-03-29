module Delegatable
  extend ActiveSupport::Concern

  included do
    def dois_count(uid, **options)
      Rails.cache.fetch("dois_count/#{uid}", expires_in: 6.hours,
                                             force: options[:force]) do
        case self
        when ClientsController
          response = Maremma.get("#{ENV['API_URL']}/clients/#{uid}")
        when ProvidersController
          response = Maremma.get("#{ENV['API_URL']}/providers/#{uid}")
        end
        response.body.to_h.dig("meta", "dois")
      end
    end

    # def prefixes_count uid
    #   if self.is_a?(ClientsController)
    #     response = Maremma.get(ENV['API_URL']+"/clients/"+uid)
    #   elsif  self.is_a?(ProvidersController)
    #     response = Maremma.get(ENV['API_URL']+"/providers/"+uid)
    #   end

    #   response.body["meta"]["prefixes"]
    # end

    # def repository_count uid
    #   if self.is_a?(ClientsController)
    #     response = Maremma.get(ENV['API_URL']+"/clients/"+uid)
    #   elsif  self.is_a?(ProvidersController)
    #     response = Maremma.get(ENV['API_URL']+"/providers/"+uid)
    #   end

    #   response.body["meta"]["repositories"]
    # end
  end
end
