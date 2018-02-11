class Client
  # include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Persistence::Model
  include Cacheable
  include Indexable


  attribute :symbol,  String,  mapping: { type: 'keyword', analyzer: "keyword" }
  attribute :region,  String,  mapping: { type: 'keyword' }
  attribute :year,  Integer,  mapping: { type: 'integer' }
  attribute :created,  Date,  mapping: { type: 'date' }
  attribute :name,  String,  mapping: { type: 'text' }
  attribute :contact_name,  String, default: "", mapping: { type: 'text' }
  attribute :contact_email,  String,  mapping: { type: 'keyword' }
  attribute :re3data,  String,  mapping: { type: 'keyword' }
  attribute :doi_quota_allowed,  Integer, default: 0, mapping: { type: 'integer' }
  attribute :version,    Integer, default: 0, mapping: { type: 'integer' }
  attribute :role_name,  String, default: "ROLE_ALLOCATOR" , mapping: { type: 'keyword' }
  attribute :is_active,  String, default: "\x01", mapping: { type: 'boolean' }
  attribute :doi_quota_used,  Integer, default: -1, mapping: { type: 'integer' }
  attribute :comments,  String,  mapping: { type: 'text' }
  attribute :domains,  String,  mapping: { type: 'text' }
  attribute :password,  String,  mapping: { type: 'text' }
  attribute :provider_id,  String,  mapping: { type: 'keyword' }
  attribute :provider_symbol,  String,  mapping: { type: 'keyword' }
  attribute :experiments,  String,  mapping: { type: 'text' }
  attribute :url,  String,  mapping: { type: 'text' }
  attribute :deleted_at,  Date,  mapping: { type: 'date' }
  

  validates :symbol, :name,  :contact_email, presence: :true
  # validates :symbol, symbol: {uniqueness: true} # {message: "This Client ID has already been taken"}
  validates :contact_email, format:  {  with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }

  before_save :set_defaults
  before_create :set_test_prefix, :validate_uniqueness #, if: Proc.new { |client| client.provider_symbol == "SANDBOX" }

  attr_accessor :target_id

  def validate_uniqueness
    r = Client.find_each.select { |client| client.symbol == self.symbol }
    unless  r.length == 0 
      fail ActiveRecord::RecordNotFound 
    end
  end


  def provider
    return nil unless provider_id.present?
      r = cached_provider_response provider_id
      r if r.present?
  end

  def self.query query, options={}
   search(
     {
       query: {
         query_string: {
           query: query+"*",
           fields: ['symbol^10', 'name^10', 'contact_email', 'region']
         }
       }
     }
   )
  end

  def self.query_filter_by field, value
    page ||= 1    
    value.respond_to?(:to_str) ? value.downcase! : value
    query = search(
      {
        query: {
          bool: {
            must: [
              { match_all: {}}
              ],
            filter: [
              { term:  { field => value}}
            ]
          }
        }
      }
    )
  end

  def self.find_by_id symbol
    clients = Client.find_each.select { |client| client.symbol === symbol }
    clients.first
  end


  def updated
    updated_at
  end


  def repository_id=(value)
    write_attribute(:re3data, value)
  end

  def repository
    return nil unless re3data.present?
    r = cached_repository_response(re3data)
    r[:data] if r.present?
  end

  def target_id=(value)
    c = Client.where(symbol: value).first
    return nil unless c.present?

    dois.update_all(datacentre: c.id)

    # update DOI count for source and target client
    cached_doi_count(force: true)
    c.cached_doi_count(force: true)
  end

  # backwards compatibility
  def member
    m = cached_member_response(provider_id)
    m[:data] if m.present?
  end

  def year
    created.to_datetime.year
  end

  def doi_quota_exceeded
    unless doi_quota_allowed.to_i > 0
      errors.add(:doi_quota, "You have excceded your DOI quota. You cannot mint DOIs anymore")
    end
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

  private

  def set_test_prefix
    # return if Rails.env.test? || prefixes.where(prefix: "10.5072").first
    #
    # prefixes << cached_prefix_response("10.5072")
  end

end
