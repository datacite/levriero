class ProvidersController < ApplicationController

  include Facetable
  include Delegatable


  before_action :set_provider, only: [:show, :update, :destroy, :getpassword]
  before_action :set_include, :authenticate_user_from_token!, :sanitize_page_params
  load_and_authorize_resource :except => [:index, :show]

  def index
    collection = Provider

    collection = filter_by_query params[:query], collection if params[:query].present?
    # collection = filter_by_provider params[:provider_id], collection if params[:provider_id].present?
    collection = filter_providers_by_client params[:client_id], collection if params[:client_id].present?

    collection = filter_by_symbol params[:id], collection if params[:id].present?
    collection = filter_by_prefix params[:prefix], collection if params[:prefix].present?
    collection = filter_by_year params[:year], collection if params[:year].present?
    collection = filter_by_region params[:region], collection if params[:region].present?


    collection = Provider.all if collection.respond_to?(:search)
    # regions    = facet_by_region params, collection
    years      = facet_by_year params, collection


    page = params[:page] || {}
    page[:number] = page[:number] && page[:number].to_i > 0 ? page[:number].to_i : 1
    page[:size] = page[:size] && (1..1000).include?(page[:size].to_i) ? page[:size].to_i : 25
    total = collection.response.hits.total
    #
    variable = case params[:sort]
      when "created" then "created"
      else "name"
    end

    ordered = case params[:sort]
        when "-name" then collection.sort_by { |hsh| hsh[variable] }.reverse
        when "-created" then collection.sort_by { |hsh| hsh[variable] }.reverse
        else collection.sort_by { |hsh| hsh[variable] }
    end

      # collection.last.symbol.ddd
    # https://github.com/elastic/elasticsearch-rails/issues/338
    @providers = collection.all unless collection.respond_to?(:each)
    @providers = Kaminari.paginate_array(ordered, total_count: total).page(page[:number]).per(page[:size])

    meta = { total: total,
             total_pages: @providers.total_pages,
             page: page[:number].to_i,
            #  regions: regions,
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

  # POST /providers
  def create
    # @provider = Provider.new(safe_params)
    @provider = Provider.create(safe_params)
    authorize! :create, @provider

    if @provider.save
      render jsonapi: @provider, status: :created, location: @provider
    else
      Rails.logger.warn @provider.errors.inspect
      render jsonapi: serialize(@provider.errors), status: :unprocessable_entity
    end
  end

  # PATCH/PUT /providers/1
  def update
    if @provider.update_attributes(safe_params)
      render jsonapi: @provider
    else
      Rails.logger.warn @provider.errors.inspect
      render jsonapi: serialize(@provider.errors), status: :unprocessable_entity
    end
  end

  # don't delete, but set deleted_at timestamp
  # a provider with clients or prefixes can't be deleted
  def destroy
    if @provider.client_count.present?
      message = "Can't delete provider that has clients."
      status = 400
      Rails.logger.warn message
      render json: { errors: [{ status: status.to_s, title: message }] }.to_json, status: status
    elsif @provider.update_attributes(is_active: "\x00", deleted_at: Time.zone.now)
      @provider.remove_users(id: "provider_id", jwt: current_user.jwt) unless Rails.env.test?
      head :no_content
    else
      Rails.logger.warn @provider.errors.inspect
      render jsonapi: serialize(@provider.errors), status: :unprocessable_entity
    end
  end

  def getpassword
    phrase = Password.new(current_user, @provider)
    response.headers['X-Consumer-Role'] = current_user && current_user.role_id || 'anonymous'
    r = {password: phrase.string }
    render jsonapi: @client, meta: r , include: @include
  end

  protected

  # Use callbacks to share common setup or constraints between actions.
  def set_provider
    @provider = Provider.query_filter_by(:symbol, params[:id]).first
    fail ActiveRecord::RecordNotFound unless @provider.present?
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
      params, only: [:name, :symbol, :contact_name, :contact_email, :country, :is_active, :created, :prefixes],
              keys: { country: :country_code }
    )
  end


  def sanitize_page_params
    params[:offset] = params[:offset].to_i
    params[:year] = params[:year].to_i if params[:year].present?
  end
end
