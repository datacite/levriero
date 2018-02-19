class DataCentersController < ApplicationController
  before_action :set_client, only: [:show]
  before_action :set_include

  def index
    if params[:id].present?
      response = Client.find(params[:id])
    elsif params[:ids].present?
      response = Client.query(params[:ids])
    else
      page = (params.dig(:page, :number) || 1).to_i
      size = (params.dig(:page, :size) || 25).to_i
      from = (page - 1) * size

      sort = case params[:sort]
             when "name" then "name"
             when "-name" then "name: desc"
             when "created" then "created"
             else "created"
             end

      params[:query] ||= "*"
      response = Client.query(params[:query], from: from, size: size, sort: sort)
      total = response.total
      total_pages = (total.to_f / size).ceil

      years = facet_by_year(response.response.aggregations.years.buckets)
      providers = facet_by_provider(response.response.aggregations.providers.buckets)
    end

    @clients = Kaminari.paginate_array(response.results, total_count: total).page(page).per(size)

    meta = {
      total: total,
      total_pages: total_pages,
      page: page,
      years: years
    }

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
