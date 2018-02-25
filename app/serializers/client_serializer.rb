class ClientSerializer < ActiveModel::Serializer
  attributes :name, :symbol, :year, :contact_name, :contact_email, :domains, :url, :is_active, :created, :updated

  belongs_to :provider

  def created
    object.created.strftime("%FT%TZ")
  end

  def updated
    object.updated.strftime("%FT%TZ")
  end
end
