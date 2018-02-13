require "countries"

class Provider 
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Persistence::Model
  include ActiveModel::Validations

  # # include helper module for managing associated users
  include Indexable
  include Cacheable

  attribute :symbol,  String,  mapping: { type: 'keyword', analyzer: "keyword" }
  attribute :region,  String,  mapping: { type: 'keyword' }
  attribute :year,  Integer,  mapping: { type: 'integer' }
  attribute :name,  String,  mapping: { type: 'text' }
  attribute :created,  Date,  mapping: { type: 'date' }
  attribute :contact_name,  String, default: "", mapping: { type: 'text' }
  attribute :contact_email,  String,  mapping: { type: 'keyword' }
  attribute :country_code,  String,  mapping: { type: 'keyword' }
  attribute :website,  String,  mapping: { type: 'keyword' }
  attribute :doi_quota_allowed,  Integer, default: 0, mapping: { type: 'integer' }
  attribute :version,    Integer, default: 0, mapping: { type: 'integer' }
  attribute :role_name,  String, default: "ROLE_ALLOCATOR" , mapping: { type: 'keyword' }
  attribute :is_active,  String, default: "\x01", mapping: { type: 'boolean' }
  attribute :password,  String, mapping: { type: 'text' }
  attribute :doi_quota_used,  Integer, default: -1, mapping: { type: 'integer' }
  attribute :prefixes,  String,  mapping: { type: 'text' }


  validates :symbol, :name, :contact_name, :contact_email, presence: :true
  # validates :symbol, symbol: {uniqueness: true} # {message: "This Client ID has already been taken"}
  validates :contact_email, format:  {  with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }

  before_create :set_test_prefix, :instance_validations

  def instance_validations
    validates_with UniquenessValidator
  end

  def year
    created.to_datetime.year
  end

  def clients
    cached_clients_provider_id(symbol)
  end


  def country_name
    return nil unless country_code.present?

    ISO3166::Country[country_code].name
  end

  def regions
    { "AMER" => "Americas",
      "APAC" => "Asia Pacific",
      "EMEA" => "EMEA" }
  end

  def region_name
    regions[region]
  end

  def logo_url
    "#{ENV['CDN_URL']}/images/members/#{symbol.downcase}.png"
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

  def self.query_prefixes prefixes, options={}
  search(
    {
      query: {
        query_string: {
          query: prefixes,
          fields: ['prefixes']
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
    providers = Provider.find_each.select { |provider| provider.symbol === symbol }
    providers.first
  end

  # show all clients for admin
  def client_count
    counts = Client.search(
      {
        query: {
          bool: {
            must: [
              { match_all: {} }
             ],
            filter: [
              { term:  { provider_id: symbol.downcase}}
            ]
          }
        },
        size: 0,
        aggregations: {
          clients_count: {
            terms: {
              field: :year
            }
          }
        }
      }
    ).response.aggregations.clients_count.buckets
    counts.map! { |k| { id: k[:key], title: k[:key], count: k[:doc_count] } }
  end

  def dois_count
    counts = Doi.search(
      {
        query: {
          bool: {
            must: [
              { match_all: {} }
             ],
            filter: [
              { term:  { client_id: symbol}}
            ]
          }
        },
        size: 0,
        aggregations: {
          dois_count: {
            terms: {
              field: :published
            }
          }
        }
      }
    ).response.aggregations.dois_count.buckets
    counts.map! { |k| { id: k[:key], title: k[:key], count: k[:doc_count] } }
  end

  def to_jsonapi
    attributes = self.attributes
    # attributes.transform_keys! { |key| key.tr('_', '-') }
    params = { "data" => { "type" => "providers", "attributes" => attributes } }
    params
  end

  def updated
    updated_at.iso8601
  end


  def user_url
    ENV["VOLPINO_URL"] + "/users?provider-id=" + symbol.downcase
  end

  private

  def set_region
    if country_code.present?
      r = ISO3166::Country[country_code].world_region
    else
      r = nil
    end
    # write_attribute(:region, r)
    region =r
  end

  def set_test_prefix
    # return if Rails.env.test? || prefixes.where(prefix: "10.5072").first
    #
    # prefixes << cached_prefix_response("10.5072")
  end

end
