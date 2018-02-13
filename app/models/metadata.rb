# class Metadata 
#   # define table and attribute names
#   # uid is used as unique identifier, mapped to id in serializer
#   #
#   include Bolognese::Utils
#   include Bolognese::DoiUtils

#   alias_attribute :uid, :id
#   attr_readonly :uid
#   alias_attribute :created_at, :created
#   alias_attribute :updated_at, :updated
#   validates_presence_of :dataset, :metadata_version
#   validates_uniqueness_of :uid, message: "This name has already been taken"
#   validates_numericality_of :version, if: :version?
#   validates :xml, metadata: true
#   validate :freeze_uid, :on => :update
#   validates_numericality_of :metadata_version, if: :metadata_version?


#   belongs_to :doi, foreign_key: :dataset

#   before_create { self.created = Time.zone.now.utc.iso8601 }

#   def freeze_uid
#     errors.add(:uid, "cannot be changed") if self.uid_changed? || self.id_changed?
#   end

#   # def dataset_id=(value)
#   #   r = Dataset.where(doi: value).select(:id, :doi, :datacentre, :created).first
#   #   fail ActiveRecord::RecordNotFound unless r.present?
#   #
#   #   write_attribute(:dataset, r.id)
#   # end
# end
