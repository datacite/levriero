class ProviderSerializer < ActiveModel::Serializer
  cache key: 'provider'
  type 'providers'

  attributes :name, :symbol, :year, :contact_name, :contact_email, :logo_url, :is_active, :created, :updated

  has_many :clients
  has_many :prefixes

  def id
    object.symbol.downcase
  end

  def created
    object.created.strftime("%FT%TZ")
  end
end
