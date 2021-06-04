class Doi < Base
  include Searchable
  include Indexable

  def self.get_query_url(options = {})
    if options[:id].present?
      "#{url}/#{options[:id]}"
    else
      params = { query: options.fetch(:query, nil),
                 member_type: options.fetch("member-type", nil),
                 region: options.fetch(:region, nil),
                 year: options.fetch(:year, nil),
                 "page[size]" => options.dig(:page, :size),
                 "page[number]" => options.dig(:page, :number) }.compact
      "#{url}?#{URI.encode_www_form(params)}"
    end
  end

  def self.parse_data(result, options = {})
    return nil if result.blank? || result["errors"]

    if options[:id].present?
      item = result.body.fetch("data", {})
      return nil if item.blank?

      { data: parse_item(item) }
    else
      items = result.body.fetch("data", [])
      meta = result.body.fetch("meta", {})

      { data: parse_items(items), meta: meta }
    end
  end
end
