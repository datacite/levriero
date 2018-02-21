class ProvidersController < ApplicationController
  include Facetable
  include Delegatable

  before_action :set_provider, only: [:show, :update, :destroy]
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
      response = Provider.find_by_id(params[:id])
    elsif params[:ids].present?
      response = Provider.query(params[:ids])
    else
      params[:query] ||= "*"
      response = Provider.query(params[:query], year: params[:year], from: from, size: size, sort: sort)
    end

    total = response.total
    total_pages = (total.to_f / size).ceil
    years = total > 0 ? facet_by_year(response.response.aggregations.years.buckets) : nil

    @providers = Kaminari.paginate_array(response.results, total_count: total).page(page).per(size)

    meta = {
      total: total,
      total_pages: total_pages,
      page: page,
      years: years
    }

    render jsonapi: @providers, meta: meta, include: @include
  end

  def show
    meta = {
             clients: @provider.client_count,
             dois: dois_count(@provider.symbol)
            }.compact

    render jsonapi: @provider, meta: meta, include: @include
  end

  def create
    # @provider = Provider.new(safe_params)
    @provider = Provider.create(safe_params)
    authorize! :create, @provider

    return render json: { errors: [{ status: "422", title: "This ID has already been taken" }] }.to_json, status: :unprocessable_entity unless @provider.respond_to?(:save)

    if @provider.save
      render jsonapi: @provider, status: :created, location: @provider
    else
      Rails.logger.warn @provider.errors.inspect
      render jsonapi: serialize(@provider.errors), status: :unprocessable_entity
    end
  end

  def update
    return render json: { errors: [{ status: "422", title: "Symbol cannot be changed" }] }.to_json, status: :unprocessable_entity unless @provider.symbol.casecmp(safe_params[:symbol]) == 0
    if @provider.update_attributes(safe_params)
      render jsonapi: @provider
    else
      Rails.logger.warn @provider.errors.inspect
      render jsonapi: serialize(@provider.errors), status: :unprocessable_entity
    end
  end

  def destroy
    if @provider.destroy
      head :no_content
    else
      Rails.logger.warn @provider.errors.inspect
      render jsonapi: serialize(@provider.errors), status: :unprocessable_entity
    end
  end

  protected

  def set_provider
    @provider = Provider.find_by_id(params[:id])
    fail Elasticsearch::Transport::Transport::Errors::NotFound unless @provider.present?
  end

  private

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore }.join(",")
      @include = [@include]
    else
      @include = nil
    end
  end

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: [:id, :name, :symbol, "contact-name", "contact-email", "country-code", "is-active", :created, :updated, :prefixes],
              keys: { "contact-name" => :contact_name, "contact-email" => :contact_email, "country-code" => :country_code, "is-active" => :is_active }
    )
  end
end
