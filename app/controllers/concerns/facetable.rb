module Facetable
  extend ActiveSupport::Concern

  included do

    def filter_by_client client_id, collection
        collection = collection.respond_to?(:search) ? collection.query_filter_by(:client_id, client_id) : collection.select {|item| item.client_id == client_id}
    end

    def filter_by_provider provider_id, collection
      collection = collection.respond_to?(:search) ? collection.query_filter_by(:provider_id, provider_id) : collection.select {|item| item.provider_id == provider_id}
    end

    def filter_by_publication published, collection
      collection = collection.respond_to?(:search) ? collection.query_filter_by(:published, published) : collection.select {|item| item.published == published}
    end

    def filter_by_symbol symbol, collection
        collection =collection.select {|item| item.symbol == symbol} unless collection.respond_to?(:search)
        collection = collection.query_filter_by :symbol, symbol if collection.respond_to?(:search)
    end

    def filter_by_query query, collection
      collection.query(query)
    end

    def filter_by_year year, collection
      collection = collection.respond_to?(:search) ? collection.query_filter_by(:year, year) : collection.select {|item| item.year == year}
    end

    def filter_by_region region, collection
      collection = collection.respond_to?(:search) ? collection.query_filter_by(:region, region) : collection.select {|item| item.region == region}
    end


    def filter_by_ids ids, collection
      r = []
      ids = ids.split(",")
      if collection.respond_to?(:search)
        # ids.each { |id|  r << Client.query_filter_by(:symbol, id).first }
        ids.each { |id|  r << Client.find_by_id(id) if Client.find_by_id(id).present? }
      else
        ids.each { |id|  r << collection.select {|item| item.symbol == item}.first }
      end
      enumerator = r.to_enum(:each)
      enumerator.each do |record| 
        puts record
        puts record.class.name
      end
      # enumerator.ddd
      enumerator
      # r
    end

    # def filter_by_prefix prefix, collection
    #   collection = collection.respond_to?(:search) ? 
    #     collection.query_filter_by(:prefix, prefix) 
    #   : collection.select {|item| item.prefix == prefix}

      

    #   prefix = cached_prefix_response(prefix_id)
    #   collection = collection.includes(:prefixes).where('prefix.id' => prefix.id)
    # end

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
        years = collection.group_by{|record| record[:year]}.map{ |k,v| { id: k.to_s, title: k.to_s, count: v.count }}
      else
        # years = collection.where.not(created: nil).order("YEAR(allocator.created) DESC").group("YEAR(allocator.created)").count
        years = collection.group_by{|record| record.year}
        years = years.map { |k,v| { id: k.to_s, title: k.to_s, count: v.count } }
      end
    end

    def get_providers collection, **options
      Rails.cache.fetch("providers_set", expires_in: 6.hours, force: options[:force]) do
        providers = collection.group_by{|record| record[:provider_id]}
        providers = providers.map { |k,v| { id: k.to_s.upcase, title: k.to_s, count: v.count } }
        providers
      end
     end
    end

    def filter_providers_by_client client_id, collection, **options
      Rails.cache.fetch("providers_by_client", expires_in: 6.hours, force: options[:force]) do
        client =  Client.query_filter_by(:symbol, params[:client_id])
        if collection = collection.respond_to?(:search) 
          collection = Provider.query_filter_by(:symbol, client.first[:provider_id])        
        else
          collection = collection.select {|provider| provider.symbol == client.provider_id}
        end
      end
     end
end
