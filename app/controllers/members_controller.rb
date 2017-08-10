class MembersController < ApplicationController
  before_action :set_member, only: [:show, :update, :destroy]

  # GET /members
  def index
    @members = Member.all

    page = params[:page] || { number: 1, size: 1000 }

    @members = Member.order(:name).page(page[:number]).per_page(page[:size])

    meta = { total: @members.total_entries,
             total_pages: @members.total_pages ,
             page: page[:number].to_i,
            #  member_types: member_types,
            #  regions: regions,
            }

    paginate json: @members, meta: meta, include:['datacenters', 'prefixes'], per_page: 25
  end

  # GET /members/1
  def show
      render json: @member, include:['datacenters', 'prefixes']
  end

  # POST /members
  def create
    @member = Member.new(member_params)

    if @member.save
      render json: @member, status: :created, location: @member
    else
      render json: serialize(@member.errors), status: :unprocessable_entity
    end
  end

  # PATCH/PUT /members/1
  def update
    if @member.update(member_params)
      render json: @member
    else
      render json: serialize(@member.errors), status: :unprocessable_entity
    end
  end

  # DELETE /members/1
  def destroy
    @member.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_member
      @member = Member.find_by(symbol: params[:id])
      fail ActiveRecord::RecordNotFound unless @member.present?
    end

    # Only allow a trusted parameter "white list" through.
    def member_params
      params.require(:data)
        .require(:attributes)
        .permit(:comments, :contact_email, :contact_name, :description, :member_type, :year, :image, :region, :country_code, :website, :logo, :doi_quota_allowed, :doi_quota_used, :is_active, :name, :password, :role_name, :member_id, :version, :experiments)

      mb_params= ActiveModelSerializers::Deserialization.jsonapi_parse(params).transform_keys!{ |key| key.to_s.snakecase }
      mb_params["symbol"] = mb_params["member_id"]
      mb_params["password"] = encrypt_password(mb_params["password"])
      mb_params
    end
end
