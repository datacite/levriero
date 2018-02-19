class ClientSerializer < ActiveModel::Serializer
  cache key: 'client'
  type 'clients'

  attributes :name, :symbol, :year, :contact_name, :contact_email, :provider_id, :domains, :url, :is_active, :created, :updated

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
