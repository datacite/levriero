class User
  include Authenticable

  # include jwt encode and decode
  # ROLES = %i[admin superadmin staff user banned guest]



  attr_accessor :name, :uid, :email, :role, :jwt, :orcid, :member_id, :datacenter_id

  def initialize(payload)
    # payload = decode_token(token)

    # @jwt = JsonWebToken.encode_token(payload)
    @uid = payload.fetch("uid", nil)
    @name = payload.fetch("name", nil)
    @email = payload.fetch("email", nil)
    @role = payload.fetch("role", nil)
    @member_id = payload.fetch("member_id", nil)
    @datacenter_id = payload.fetch("datacenter_id", nil)
  end

  # Helper method to check for admin user
  def generate_token
    @jwt
  end



  # Helper method to check for admin user
  def is_admin?
    role == "staff_admin"
  end

  # Helper method to check for admin or staff user
  def is_admin_or_staff?
    ["staff_admin", "staff_user"].include?(role)
  end
end
