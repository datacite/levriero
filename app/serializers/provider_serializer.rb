class ProviderSerializer < ActiveModel::Serializer
  cache key: 'provider'
  type 'provider'

  attributes :name, :symbol, :year, :contact_name, :contact_email, :logo_url, :is_active, :has_password, :created, :updated

  has_many :clients
  has_many :prefixes

  def id
    object.symbol.downcase
  end

  def has_password
    object.password.present?
  end

  def is_active
    object.is_active == "\u0001" ? true : false
  end
end
