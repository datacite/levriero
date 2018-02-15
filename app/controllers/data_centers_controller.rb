class DataCentersController < ApplicationController
  before_action :set_client, only: [:show]
  before_action :set_include

  def index
 
    collection = Client
    collection = filter_by_query params[:query], collection if params[:query].present?

    collection = filter_by_symbol params[:id], collection if params[:id].present?
    collection = filter_by_provider params[:provider_id], collection if params[:provider_id].present?
    collection = filter_by_prefix params[:prefix], collection if params[:prefix].present?
    collection = filter_by_year params[:year], collection if params[:year].present?
 
    collection = filter_by_ids params[:ids], collection if params[:ids].present?
 
    collection = Client.all if collection.respond_to?(:search)
    # regions    = facet_by_region params, collection
    years      = facet_by_year params, collection

    page = params[:page] || {}
    page[:number] = page[:number] && page[:number].to_i > 0 ? page[:number].to_i : 1
    page[:size] = page[:size] && (1..1000).include?(page[:size].to_i) ? page[:size].to_i : 25
    total = collection.count
    providers = get_providers collection
    
    variable = case params[:sort]
      when "created" then "created"
      else "name"
    end

    ordered = case params[:sort]
        when "-name" then collection.sort_by { |hsh| hsh[variable] }.reverse
        when "-created" then collection.sort_by { |hsh| hsh[variable] }.reverse
        else collection.sort_by { |hsh| hsh[variable] }
    end


    # https://github.com/elastic/elasticsearch-rails/issues/338
    @clients = collection.all unless collection.respond_to?(:each)
    @clients = Kaminari.paginate_array(ordered, total_count: total).page(page[:number]).per(page[:size])

    meta = { total: total,
             total_pages: @clients.total_pages,
             page: page[:number].to_i,
             providers: providers,
             years: years }

    render jsonapi: @clients, meta: meta, include: @include, each_serializer: DataCenterSerializer
  end

  def show
    render jsonapi: @client, include: @include, serializer: DataCenterSerializer
  end

  protected

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore }.join(",")
      @include = [@include]
    else
      @include = nil
    end
  end

  def set_client
    @client = Client.where(symbol: params[:id]).first
    fail ActiveRecord::RecordNotFound unless @client.present?
  end
end
