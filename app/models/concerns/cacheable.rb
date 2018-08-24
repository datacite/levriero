module Cacheable
  extend ActiveSupport::Concern

  module ClassMethods
    def cached_datacite_response(id)
      Rails.cache.fetch("datacite/#{id}", expires_in: 1.day) do
        Base.get_datacite_metadata(id)
      end
    end

    def cached_crossref_response(id)
      Rails.cache.fetch("crossref/#{id}", expires_in: 1.day) do
        Base.get_crossref_metadata(id)
      end
    end

    def cached_funder_response(id)
      Rails.cache.fetch("funders/#{id}", expires_in: 1.day) do
        FunderIdentifier.get_funder_metadata(id)
      end
    end
  end
end
