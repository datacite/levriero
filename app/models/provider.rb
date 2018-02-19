require "countries"

class Provider
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Proxy
  include Elasticsearch::Persistence::Model
  include ActiveModel::Validations

  # # include helper module for managing associated users
  include Indexable
  include Cacheable
  include Importable

  attribute :symbol, String, mapping: { type: 'keyword' }
  attribute :region, String, mapping: { type: 'keyword' }
  attribute :year, Integer, mapping: { type: 'integer' }
  attribute :name, String, mapping: { type: 'text' }
  attribute :created, DateTime, mapping: { type: :date}
  attribute :contact_name, String, default: "", mapping: { type: 'text' }
  attribute :contact_email, String, mapping: { type: 'keyword' }
  attribute :country_code, String, mapping: { type: 'keyword' }
  attribute :country_name, String, mapping: { type: 'keyword' }
  attribute :region, String, mapping: { type: 'keyword' }
  attribute :region_name, String, mapping: { type: 'keyword' }
  attribute :website, String, mapping: { type: 'keyword' }
  attribute :version, Integer, default: 0, mapping: { type: 'integer' }
  attribute :is_active, Integer, default: 1, mapping: { type: 'boolean' }
  attribute :prefixes, String, mapping: { type: 'text' }

  validates :symbol, :name, :contact_name, :contact_email, presence: :true
  # validates :symbol, symbol: {uniqueness: true} # {message: "This Client ID has already been taken"}
  validates :contact_email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i }

  #before_create :set_test_prefix, :instance_validations

  def self.safe_params
    [:name, :symbol, :year, :contact_name, :contact_email, :logo_url, :is_active, :country_code, :created, :updated, :prefixes]
  end

  def instance_validations
    validates_with UniquenessValidator
  end

  def year
    created.to_datetime.year if created.present?
  end

  def clients
    cached_clients_provider_id(symbol)
  end

  def country_name
    return nil unless country_code.present?

    ISO3166::Country[country_code].name
  end

  def region
    return nil unless country_code.present?

    ISO3166::Country[country_code].world_region
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

  # def self.find_by_id symbol
  #   provider = Provider.query_filter_by(:symbol, symbol)
  #   provider.first
  # end


  #### Work with exact value only
  def self.find_by_id symbol
    symbol.upcase!
    collection = Provider.find_each.select { |provider| provider.symbol === symbol }
    collection.first
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
end
