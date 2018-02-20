class Client
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Proxy
  include Elasticsearch::Persistence::Model
  include ActiveModel::Validations

  include Cacheable
  include Indexable
  include Importable

  index_name "clients-#{Rails.env}"

  attribute :symbol, String, mapping: { type: 'keyword' }
  attribute :year, Integer, mapping: { type: 'integer' }
  attribute :created, DateTime, mapping: { type: :date }
  attribute :name, String, mapping: { type: 'keyword' }
  attribute :contact_name, String, default: "", mapping: { type: 'text' }
  attribute :contact_email, String, mapping: { type: 'keyword' }
  attribute :re3data, String, mapping: { type: 'keyword' }
  attribute :version, Integer, default: 0, mapping: { type: 'integer' }
  attribute :is_active, Integer, default: true, mapping: { type: 'boolean' }
  attribute :domains, String, mapping: { type: 'text' }
  attribute :provider_id, String, mapping: { type: 'keyword' }
  attribute :url, String, mapping: { type: 'text' }
  attribute :deleted_at, Date, mapping: { type: 'date' }
  attribute :prefixes, String, mapping: { type: 'text' }

  validates :symbol, :name, :contact_name, :contact_email, presence: :true
  # validates :symbol, symbol: {uniqueness: true} # {message: "This Client ID has already been taken"}
  validates_format_of :contact_email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, message: "contact_email should be an email"

  #before_create :instance_validations

  def self.query(query, options={})
    search({
      from: options[:from],
      size: options[:size],
      sort: [options[:sort], "_doc"],
      query: {
        query_string: {
          query: query + "*",
          fields: ['symbol^10', 'name^10', 'contact_name^10', 'contact_email^10', '_all']
        }
      },
      aggregations: {
        years: { date_histogram: { field: 'created', interval: 'year', min_doc_count: 1 } },
        providers: { terms: { field: 'provider_id', min_doc_count: 1 } }
      },
    })
  end

  def self.safe_params
    [:id, :symbol, :name, :created, :updated, :contact_name, :contact_email, :domains, :year, :provider_id, :re3data, :provider, :url, :repository, :is_active, :deleted_at, :prefixes]
  end

  def instance_validations
    validates_with UniquenessValidator
  end

  def provider
    return nil unless provider_id.present?
    r = cached_provider_response provider_id
    r if r.present?
  end

  def self.query_filter_by(field, value)
    page ||= 1
    value.respond_to?(:to_str) ? value.downcase! : value
    query = search({
      query: {
        bool: {
          must: [
            { match_all: {} }
          ],
          filter: [
            { term: { field => value } }
          ]
        }
      }
    })
  end

  def updated
    updated_at
  end

  def to_jsonapi
    attributes = self.attributes
    attributes["contact-name"] = attributes[:contact_name]
    attributes["contact-email"] = attributes[:contact_email]

    { "data" => { "type" => "clients", "attributes" => attributes } }
  end

  def repository_id=(value)
    write_attribute(:re3data, value)
  end

  def repository
    return nil unless re3data.present?
    r = cached_repository_response(re3data)
    r[:data] if r.present?
  end

  # backwards compatibility
  def member
    m = cached_member_response(provider_id)
    m[:data] if m.present?
  end

  def year
    created.to_datetime.year
  end

  protected

  def freeze_symbol
    errors.add(:symbol, "cannot be changed") if self.symbol_changed?
  end

  def check_id
    errors.add(:symbol, ", Your Client ID must include the name of your provider. Separated by a dot '.' ") if self.symbol.split(".").first.downcase != self.provider.symbol.downcase
  end

  def user_url
    ENV["VOLPINO_URL"] + "/users?client-id=" + symbol.downcase
  end
end
