class ProviderSerializer < ActiveModel::Serializer
  # cache key: 'provider'
  # type 'providers'

  attributes :name, :symbol, :year, :contact_name, :contact_email, :logo_url, :is_active, :created, :updated, :password

  has_many :clients
  has_many :prefixes, join_table: "datacentre_prefixes"

  def id
    object.symbol.downcase
  end

  def password
    object.password.present? ? "yes" : nil
  end

  def is_active
    object.is_active == "\u0001" ? true : false
  end
end
