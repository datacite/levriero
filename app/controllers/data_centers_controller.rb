class DataCentersController < ApplicationController
  include Facetable
  include Delegatable

  before_action :set_client, only: [:show]
  before_action :authenticate_user_from_token!, :set_include
  load_and_authorize_resource :except => [:index, :show]

  def index
    page = (params.dig(:page, :number) || 1).to_i
    size = (params.dig(:page, :size) || 25).to_i
    from = (page - 1) * size

    sort = case params[:sort]
           when "-name" then { "name.keyword" => { order: 'desc' }}
           when "created" then { created: { order: 'asc' }}
           when "-created" then { created: { order: 'desc' }}
           else { "name.keyword" => { order: 'asc' }}
           end

    if params[:id].present?
      response = Client.find_by_id(params[:id])
    elsif params[:ids].present?
      response = Client.query(params[:ids])
    else
      params[:query] ||= "*"
      response = Client.query(params[:query], year: params[:year], from: from, size: size, sort: sort)
    end

    total = response.total
    total_pages = (total.to_f / size).ceil
    years = total > 0 ? facet_by_year(response.response.aggregations.years.buckets) : nil

    @clients = Kaminari.paginate_array(response.results, total_count: total).page(page).per(size)

    meta = {
      total: total,
      total_pages: total_pages,
      page: page,
      years: years
    }.compact

    render jsonapi: @clients, meta: meta, include: @include, each_serializer: DataCenterSerializer
  end

  def show
    meta = {
      dois: dois_count(@client.symbol)
    }

    render jsonapi: @client, meta: meta, include: @include, serializer: DataCenterSerializer
  end

  protected

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore }.join(",")
      @include = [@include]
    else
      @include = ["provider", "repository"]
    end
  end

  def set_client
    @client = Client.find_by_id(params[:id])
    fail Elasticsearch::Transport::Transport::Errors::NotFound unless @client.present?
  end
end
