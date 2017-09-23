class DataCenterSerializer < ActiveModel::Serializer
  cache key: 'data_center'
  type 'data_centers'
  attributes :title, :other_names, :prefixes, :member_id, :year, :created, :updated

  belongs_to :member, serializer: MemberSerializer

  def id
    object.uid
  end

  def title
    object.name
  end

  def member_id
    object.provider_id
  end

  def other_names
    []
  end

  def prefixes
    []
  end

  def created
    object.created.iso8601
  end

  def updated
    object.updated.iso8601
  end
end