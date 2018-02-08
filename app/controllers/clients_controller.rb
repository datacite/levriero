class ClientsController < ApplicationController

  include Facetable
  include Delegatable

  before_action :set_client, only: [:show, :update, :destroy, :getpassword]
  before_action :authenticate_user_from_token!, :sanitize_page_params
  before_action :set_include
  load_and_authorize_resource :except => [:index, :show]

  def index

    collection = Client
    collection = filter_by_query params[:query], collection if params[:query].present?

    collection = filter_by_symbol params[:id], collection if params[:id].present?
    # collection = filter_by_prefix params[:prefix], collection if params[:prefix].present?
    collection = filter_by_year params[:year], collection if params[:year].present?

    collection = Client.all if collection.respond_to?(:search)
    # regions    = facet_by_region params, collection
    years      = facet_by_year params, collection

    page = params[:page] || {}
    page[:number] = page[:number] && page[:number].to_i > 0 ? page[:number].to_i : 1
    page[:size] = page[:size] && (1..1000).include?(page[:size].to_i) ? page[:size].to_i : 25
    total = collection.count
    
    order = case params[:sort]
    when "-name" then "-name"
    when "created" then "created"
    when "-created" then "-created"
    else "name"
    end

    # https://github.com/elastic/elasticsearch-rails/issues/338
    @clients = collection.all unless collection.respond_to?(:each_with_hit)
    @clients = Kaminari.paginate_array(collection.sort_by! { |hsh| hsh[order] }, total_count: total).page(page[:number])

    meta = { total: total,
             total_pages: @clients.total_pages,
             page: page[:number].to_i,
            #  providers: providers,
             years: years 
            }
    
    render jsonapi: @clients, meta: meta #, include: @include
  end

  # GET /clients/1
  def show
    meta = { 
      dois: dois_count(@client.symbol)
    }

    render jsonapi: @client, meta: meta, include: @include
  end

  # POST /clients
  def create
    @client = Client.create(safe_params)
    authorize! :create, @client

    if @client.save
      render jsonapi: @client, status: :created
    else
      Rails.logger.warn @client.errors.inspect
      render jsonapi: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  # PATCH/PUT /clients/1
  def update
    if @client.update_attributes(safe_params)
      render jsonapi: @client
    else
      Rails.logger.warn @client.errors.inspect
      render json: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  # don't delete, but set deleted_at timestamp
  # a client with dois or prefixes can't be deleted
  def destroy
    if @client.dois.present?
      message = "Can't delete client that has DOIs."
      status = 400
      Rails.logger.warn message
      render json: { errors: [{ status: status.to_s, title: message }] }.to_json, status: status
    elsif @client.update_attributes(is_active: "\x00", deleted_at: Time.zone.now)
      @client.remove_users(id: "client_id", jwt: current_user.jwt) unless Rails.env.test?
      head :no_content
    else
      Rails.logger.warn @client.errors.inspect
      render jsonapi: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  def getpassword
    phrase = Password.new(current_user, @client)
    response.headers['X-Consumer-Role'] = current_user && current_user.role_id || 'anonymous'
    r = {password: phrase.string }
    render jsonapi: @client, meta: r , include: @include
  end

  protected

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore }.join(",")
      @include = [@include]
    else
      @include = ["provider_id", "repository"]
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_client
    @client = Client.query_filter_by(:symbol, params[:id]).first
    fail ActiveRecord::RecordNotFound unless @client.present?
  end

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: [:symbol, :name, :created, "contact-name", "contact-email", :domains, :provider, :url, :repository, "target-id", "is-active", "deleted-at"],
              keys: { "contact-name" => :contact_name, "contact-email" => :contact_email, "target-id" => :target_id, "is-active" => :is_active, "deleted-at" => :deleted_at }
    )
  end
  def sanitize_page_params
    params[:offset] = params[:offset].to_i
    params[:year] = params[:year].to_i if params[:year].present?
  end
end
