class ClientsController < ApplicationController
  include Facetable
  include Delegatable

  before_action :set_client, only: [:show, :update, :destroy]
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
      response = Client.query(params[:query], from: from, size: size, sort: sort)
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

    render jsonapi: @clients, meta: meta, include: @include
  end

  def show
    meta = {
      dois: dois_count(@client.symbol)
    }

    render jsonapi: @client, meta: meta, include: @include
  end

  def create
    @client = Client.create(safe_params)
    authorize! :create, @client

    return render json: { errors: [{ status: "422", title: "This ID has already been taken" }] }.to_json, status: :unprocessable_entity unless @client.respond_to?(:save)

    if @client.save
      render jsonapi: @client, status: :created
    else
      Rails.logger.warn @client.errors.inspect
      render jsonapi: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  def update
    return render json: { errors: [{ status: "422", title: "Symbol cannot be changed" }] }.to_json, status: :unprocessable_entity unless @client.symbol.casecmp(safe_params[:symbol]) == 0
    if @client.update_attributes(safe_params)
      render jsonapi: @client
    else
      Rails.logger.warn @client.errors.inspect
      render json: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  def destroy
    if @client.destroy
      render json: { errors: [{ status: "204", title: "Document has been deleted" }] }.to_json, status: :destroyed
    else
      Rails.logger.warn @client.errors.inspect
      render jsonapi: serialize(@client.errors), status: :unprocessable_entity
    end
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

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: [:id, :symbol, :name, :created, :updated, "contact-name", "contact-email", :domains, :year, "provider-id", "re3data", :provider, :url, :repository, "is-active", "deleted-at", :prefixes],
              keys: { "contact-name" => :contact_name, "contact-email" => :contact_email, "is-active" => :is_active, "deleted-at" => :deleted_at }
    )
  end
end
