module Facetable
  extend ActiveSupport::Concern

  included do
    def facet_by_year(arr)
      arr.map do |hsh|
        { "id" => hsh["key_as_string"][0..3],
          "title" => hsh["key_as_string"][0..3],
          "count" => hsh["doc_count"] }
      end
    end

    def facet_by_provider(arr)
      # generate hash with id and name for each provider in facet
      ids = arr.map { |hsh| hsh["key"] }.join(",")
      providers = Provider.find_by_ids(ids).to_a.reduce({}) do |sum, p|
        sum[p.id] = p.name
        sum
      end

      arr.map do |hsh|
        { "id" => hsh["key"],
          "title" => providers[hsh["key"]],
          "count" => hsh["doc_count"] }
      end
    end
  end
end
