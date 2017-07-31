class PrefixSerializer < ActiveModel::Serializer
  attributes :prefix, :version, :created
  belongs_to :datacentre, serializer: DatacentreSerializer
  belongs_to :allocator, serializer: AllocatorSerializer

  def id
    object.prefix
  end

  def created
    object.created.iso8601
  end
end
