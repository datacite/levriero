module Facetable
  extend ActiveSupport::Concern

  included do

    # def is_results_array?  collection
    #   collection.respond_to?(:response)
    # end

    def filter_by_symbol symbol, collection
      collection =collection.select {|item| item.symbol == symbol} unless collection.respond_to?(:search)
      collection = collection.query_filter_by :symbol, symbol if collection.respond_to?(:search)
      # collection = collection.find_each.select { |item| item.symbol == symbol }
    end

    def filter_by_query query, collection
      collection.query(query)
      # collection = collection.find_each.select { |item| item.symbol == symbol }
      # collection = collection.query(params[:query])
    end

    def filter_by_year year, collection
      collection = collection.respond_to?(:search) ? collection.query_filter_by(:year, year) : collection.select {|item| item.year == year}
      # collection = collection.select {|item| item[:year] == year} unless collection.respond_to?(:search)
      # collection = collection.query_filter_by :year, year if collection.respond_to?(:search)
      # puts collection.respond_to?(:search)
      # collection = collection.find_each.select { |item| item.symbol == symbol }
    end

    def filter_by_region region, collection
      collection = collection.respond_to?(:search) ? collection.query_filter_by(:region, region) : collection.select {|item| item.region == region}
      # collection = collection.select {|item| item.region == region} unless collection.respond_to?(:search)
      # collection = collection.query_filter_by :region, region if collection.respond_to?(:search)
      # collection = collection.find_each.select { |item| item.symbol == symbol }
    end

    def filter_by_prefix prefix_id, collection
      prefix = cached_prefix_response(prefix_id)
      collection = collection.includes(:prefixes).where('prefix.id' => prefix.id)
    end

    def facet_by_region params, collection
      if params[:region].present?
        regions = [{ id: params[:region],
                     title: REGIONS[params[:region].upcase],
                     count: collection.group_by{|record| record[:region]}.map{ |k,v| { id: k.to_s, title: k.to_s, count: v.count } }}]
      else
        # regions = collection.where.not(region: nil).group(:region).count
        regions = collection.group_by{|record| record[:region]}
        regions = regions.map { |k,v| { id: k.downcase, title: REGIONS[k], count: v.count } }
      end
    end

    def facet_by_year params, collection
      if params[:year].present?
        years = [{ id: params[:year],
                   title: params[:year],
                   count: collection.group_by{|record| record[:year]}.map{ |k,v| { id: k.to_s, title: k.to_s, count: v.count } }}]
      else
        # years = collection.where.not(created: nil).order("YEAR(allocator.created) DESC").group("YEAR(allocator.created)").count
        years = collection.group_by{|record| record[:year]}
        years = years.map { |k,v| { id: k.to_s, title: k.to_s, count: v.count } }
      end
    end

  end
end
