module Indexable
  extend ActiveSupport::Concern

  module ClassMethods
    # don't raise an exception when not found
    def find_by_id(id, options={})
      return nil unless id.present?

      __elasticsearch__.find(id.downcase)
    rescue Elasticsearch::Transport::Transport::Errors::NotFound, Elasticsearch::Persistence::Repository::DocumentNotFound
      nil
    end

    def find_by_ids(ids, options={})
      options[:sort] ||= { "_doc" => { order: 'asc' }}

      __elasticsearch__.search({
        from: options[:from] || 0,
        size: options[:size] || 25,
        sort: [options[:sort]],
        query: {
          ids: {
            values: ids.split(",").map(&:downcase)
          }
        },
        aggregations: query_aggregations
      })
    end

    def query(query, options={})
      __elasticsearch__.search({
        from: options[:from],
        size: options[:size],
        sort: [options[:sort]],
        query: {
          bool: {
            must: {
              query_string: {
                query: query + "*",
                fields: query_fields
              }
            },
            filter: query_filter(options)
          }
        },
        aggregations: query_aggregations
      })
    end

    def query_fields
      ['symbol^10', 'name^10', 'contact_name^10', 'contact_email^10', '_all']
    end

    def query_filter(options = {})
      return nil unless options[:year].present?

      {
        terms: {
          year: options[:year].split(",")
        }
      }
    end

    def recreate_index(options={})
      client     = self.gateway.client
      index_name = self.index_name

      client.indices.delete index: index_name rescue nil if options[:force]
      client.indices.create index: index_name, body: { settings:  {"index.requests.cache.enable": true }}
    end
  end
end
