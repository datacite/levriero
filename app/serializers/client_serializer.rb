class ClientSerializer < ActiveModel::Serializer
  cache key: 'client'
  type 'clients'


  attributes :name, :symbol, :year, :contact_name, :contact_email, :domains, :url, :is_active, :created, :updated

  has_many :prefixes
  belongs_to :provider
  belongs_to :repository, serializer: RepositorySerializer

  def id
    object.symbol.downcase
  end

  def provider_id
    object.provider_symbol
  end

  def created
    object.created.strftime("%FT%TZ")
  end

  def updated
    object.updated.iso8601
  end
end
