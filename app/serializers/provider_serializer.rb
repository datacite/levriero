class ProviderSerializer < ActiveModel::Serializer
  attributes :name, :symbol, :year, :contact_name, :contact_email, :logo_url, :is_active, :created, :updated

  def created
    object.created.strftime("%FT%TZ")
  end

  def updated
    object.updated.strftime("%FT%TZ")
  end
end
