module Authenticable
  extend ActiveSupport::Concern

  require "jwt"
  require "base64"

  included do
    # encode JWT token using SHA-256 hash algorithm
    def encode_token(payload)
      # replace newline characters with actual newlines
      private_key = OpenSSL::PKey::RSA.new(ENV["JWT_PRIVATE_KEY"].to_s.gsub(
                                             '\n', "\n"
                                           ))
      JWT.encode(payload, private_key, "RS256")
    rescue JSON::GeneratorError => e
      Rails.logger.error "JSON::GeneratorError: #{e.message} for #{payload}"
      nil
    end

    # decode JWT token using SHA-256 hash algorithm
    def decode_token(token)
      public_key = OpenSSL::PKey::RSA.new(ENV["JWT_PUBLIC_KEY"].to_s.gsub('\n',
                                                                          "\n"))
      payload = (JWT.decode token, public_key, true,
                            { algorithm: "RS256" }).first

      # check whether token has expired
      return {} unless Time.now.to_i < payload["exp"].to_i

      payload
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT::DecodeError: #{e.message} for #{token}"
      {}
    rescue OpenSSL::PKey::RSAError => e
      public_key = ENV["JWT_PUBLIC_KEY"].presence || "nil"
      Rails.logger.error "OpenSSL::PKey::RSAError: #{e.message} for #{public_key}"
      {}
    end

    # basic auth
    def encode_auth_param(username: nil, password: nil)
      return nil unless username.present? && password.present?

      ::Base64.strict_encode64("#{username}:#{password}")
    end

    # basic auth
    def decode_auth_param(username: nil, password: nil)
      return {} unless username.present? && password.present?

      user = if username.include?(".")
               Client.where(symbol: username.upcase).first
             else
               Provider.unscoped.where(symbol: username.upcase).first
             end

      return {} unless user && secure_compare(user.password,
                                              encrypt_password_sha256(password))

      uid = username.downcase

      get_payload(uid: uid, user: user)
    end

    def get_payload(uid: nil, user: nil)
      roles = {
        "ROLE_ADMIN" => "staff_admin",
        "ROLE_ALLOCATOR" => "provider_admin",
        "ROLE_DATACENTRE" => "client_admin",
      }
      payload = {
        "uid" => uid,
        "role_id" => roles.fetch(user.role_name, "user"),
        "name" => user.name,
        "email" => user.contact_email,
      }

      if uid.include? "."
        payload["provider_id"] = uid.split(".", 2).first
        payload["client_id"] = uid
      elsif uid != "admin"
        payload["provider_id"] = uid
      end

      payload
    end

    # constant-time comparison algorithm to prevent timing attacks
    # from Devise
    def secure_compare(a, b)
      return false if a.blank? || b.blank? || a.bytesize != b.bytesize

      l = a.unpack "C#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end
  end

  module ClassMethods
    # encode token using SHA-256 hash algorithm
    def encode_token(payload)
      # replace newline characters with actual newlines
      private_key = OpenSSL::PKey::RSA.new(ENV["JWT_PRIVATE_KEY"].to_s.gsub(
                                             '\n', "\n"
                                           ))
      JWT.encode(payload, private_key, "RS256")
    rescue OpenSSL::PKey::RSAError => e
      Rails.logger.error e.inspect

      nil
    end

    # basic auth
    def encode_auth_param(username: nil, password: nil)
      return nil unless username.present? && password.present?

      ::Base64.strict_encode64("#{username}:#{password}")
    end

    # generate JWT token
    def generate_token(attributes = {})
      payload = {
        uid: attributes.fetch(:uid, "0000-0001-5489-3594"),
        name: attributes.fetch(:name, "Josiah Carberry"),
        email: attributes.fetch(:email, nil),
        provider_id: attributes.fetch(:provider_id, nil),
        client_id: attributes.fetch(:client_id, nil),
        role_id: attributes.fetch(:role_id, "staff_admin"),
        iat: Time.now.to_i,
        exp: Time.now.to_i + attributes.fetch(:exp, 30),
      }.compact

      encode_token(payload)
    end

    def get_payload(uid: nil, user: nil)
      roles = {
        "ROLE_ADMIN" => "staff_admin",
        "ROLE_ALLOCATOR" => "provider_admin",
        "ROLE_DATACENTRE" => "client_admin",
      }
      payload = {
        "uid" => uid,
        "role_id" => roles.fetch(user.role_name, "user"),
        "name" => user.name,
        "email" => user.contact_email,
      }

      if uid.include? "."
        payload["provider_id"] = uid.split(".", 2).first
        payload["client_id"] = uid
      elsif uid != "admin"
        payload["provider_id"] = uid
      end

      payload
    end
  end
end
