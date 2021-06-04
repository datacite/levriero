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

    def cached_orcid_response(id)
      Rails.cache.fetch("orcid/#{id}", expires_in: 1.day) do
        Base.get_orcid_metadata(id)
      end
    end

    def cached_ror_response(id)
      Rails.cache.fetch("ror/#{id}", expires_in: 1.day) do
        AffiliationIdentifier.get_ror_metadata(id)
      end
    end

    def cached_doi_ra(doi)
      Rails.cache.fetch("ras/#{doi}", expires_in: 1.day) do
        prefix = Base.validate_prefix(doi)
        Base.get_doi_ra(prefix)
      end
    end

    def cached_crossref_member_id(id)
      Rails.cache.fetch("member_ids/#{id}", expires_in: 1.day) do
        Base.get_crossref_member_id(id)
      end
    end
  end
end
