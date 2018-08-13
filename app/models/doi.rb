class Doi
  include Searchable

  include Importable

  include Indexable

  attr_reader :doi, :xml, :created, :date_published, :date_registered, :date_updated

  def initialize(item, options={})
    attributes = item.fetch('attributes', {})
    @doi = item.fetch("doi", nil)
    @xml = item.fetch("xml", nil)
    @created = attributes.fetch("created_at", nil)
    @date_published = attributes.fetch("updated_at", nil)
    @date_registered = attributes.fetch("updated_at", nil)
    @date_updated = attributes.fetch("updated_at", nil)
  end

  def to_jsonapi
    attributes = {
      "doi" => doi,
      #"identifier" => identifier,
      #"url" => url,
      #"creator" => author,
      #"title" => title,
      #"publisher" => publisher,
      #"resource-type-subtype" => additional_type,
      #"version" => version,
      #"schema-version" => schema_version,
      "xml" => xml,
      #"client-id" => client_id,
      #"provider-id" => provider_id,
      #"resource-type-id" => resource_type_general,
      #"prefix" => prefix,
      #"state" => aasm_state,
      #"source" => source,
      #"is-active" => is_active == "\x01",
      "created" => created,
      "published" => date_published,
      "registered" => date_registered,
      "updated" => date_updated }

    { "id" => doi, "type" => "dois", "attributes" => attributes }
  end

  def self.safe_params
    [:doi, :xml, :created, :published, :registered, :updated]
  end
  
  def self.get_query_url(options={})
    if options[:id].present?
      "#{url}/#{options[:id]}"
    else
      params = { query: options.fetch(:query, nil),
                 member_type: options.fetch("member-type", nil),
                 region: options.fetch(:region, nil),
                 year: options.fetch(:year, nil),
                 "page[size]" => options.dig(:page, :size),
                 "page[number]" => options.dig(:page, :number) }.compact
      url + "?" + URI.encode_www_form(params)
    end
  end

  def self.parse_data(result, options={})
    return nil if result.blank? || result['errors']

    if options[:id].present?
      item = result.body.fetch("data", {})
      return nil unless item.present?

      { data: parse_item(item) }
    else
      items = result.body.fetch("data", [])
      meta = result.body.fetch("meta", {})

      { data: parse_items(items), meta: meta }
    end
  end
end
