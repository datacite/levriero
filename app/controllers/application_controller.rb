class ApplicationController < ActionController::API
  include Authenticable
  include CanCan::ControllerAdditions
  include ErrorSerializable
  require "facets/string/snakecase"

  # include helper module for caching infrequently changing resources
  include Cacheable
  include Facetable

  attr_accessor :current_user

  # pass ability into serializer
  serialization_scope :current_ability

  before_action :default_format_json, :transform_params
  after_action :set_jsonp_format, :set_consumer_header

  # from https://github.com/spree/spree/blob/master/api/app/controllers/spree/api/base_controller.rb
  def set_jsonp_format
    if params[:callback] && request.get?
      self.response_body = "#{params[:callback]}(#{response.body})"
      headers["Content-Type"] = "application/javascript"
    end
  end

  def set_consumer_header
    if current_user
      response.headers["X-Credential-Username"] = current_user.uid
    else
      response.headers["X-Anonymous-Consumer"] = true
    end
  end

  def default_format_json
    request.format = :json if request.format.html?
  end

  # convert parameters with hyphen to parameters with underscore.
  # https://stackoverflow.com/questions/35812277/fields-parameters-with-hyphen-in-ruby-on-rails
  def transform_params
    params.transform_keys! { |key| key.tr("-", "_") }
  end

  def authenticate_user_from_token!
    token = token_from_request_headers
    return false if token.blank?

    @current_user = User.new(token)
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  # from https://github.com/nsarno/knock/blob/master/lib/knock/authenticable.rb
  def token_from_request_headers
    request.headers["Authorization"]&.split&.last
  end

  unless Rails.env.development?
    rescue_from *RESCUABLE_EXCEPTIONS do |exception|
      status = case exception.class.to_s
               when "CanCan::AccessDenied", "JWT::DecodeError" then 401
               when "Elasticsearch::Transport::Transport::Errors::NotFound", "AbstractController::ActionNotFound", "ActionController::RoutingError" then 404
               when "ActiveModel::ForbiddenAttributesError", "ActionController::ParameterMissing", "ActionController::UnpermittedParameters", "NoMethodError" then 422
               else 400
               end

      message = case status
                when 404
                  "The resource you are looking for doesn't exist."
                when 401
                  "You are not authorized to access this page."
                else
                  exception.message
                end

      render json: { errors: [{ status: status.to_s, title: message }] }.to_json,
             status: status
    end
  end

  protected

  def is_admin_or_staff?
    current_user&.is_admin_or_staff? ? 1 : 0
  end
end
