require "countries"

class Provider
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Proxy
  include Elasticsearch::Persistence::Model
  include ActiveModel::Validations

  include Indexable
  include Cacheable
  include Importable

  # use different index for testing
  index_name Rails.env.test? ? "providers-test" : "providers"

  attribute :id, String, mapping: { type: 'keyword', normalizer: "case_insensitive" }
  attribute :symbol, String, mapping: { type: 'keyword' }
  attribute :region, String, mapping: { type: 'keyword' }
  attribute :year, Integer, mapping: { type: 'integer' }
  attribute :name, String, mapping: { type: 'text', fields: { keyword: { type: "keyword" }}}
  attribute :created, DateTime, mapping: { type: :date }
  attribute :contact_name, String, default: "", mapping: { type: 'text' }
  attribute :contact_email, String, mapping: { type: 'keyword' }
  attribute :country_code, String, mapping: { type: 'keyword' }
  attribute :country_name, String, mapping: { type: 'keyword' }
  attribute :region, String, mapping: { type: 'keyword' }
  attribute :region_name, String, mapping: { type: 'keyword' }
  attribute :website, String, mapping: { type: 'keyword' }
  attribute :version, Integer, default: 0, mapping: { type: 'integer' }
  attribute :is_active, Integer, default: true, mapping: { type: 'boolean' }
  attribute :prefixes, String, mapping: { type: 'text' }

  validates :symbol, :name, :contact_name, :contact_email, presence: :true
  validates_format_of :contact_email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, message: "contact_email should be an email"
  validates_with UniquenessValidator, :if => :new_record?

  def self.safe_params
    [:symbol, :name, :year, :contact_name, :contact_email, :logo_url, :is_active, :country_code, :created, :updated, :prefixes]
  end

  def id
    symbol.downcase
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
    { "data" => { "type" => "providers", "attributes" => attributes } }
  end

  def updated
    updated_at.iso8601
  end

  def user_url
    ENV["VOLPINO_URL"] + "/users?provider-id=" + symbol.downcase
  end
end
