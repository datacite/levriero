module Indexable
  extend ActiveSupport::Concern
  
  
  included do

  end

  module ClassMethods
    def recreate_index(options={})
      client     = self.gateway.client
      index_name = self.index_name

      client.indices.delete index: index_name rescue nil if options[:force]
      client.indices.create index: index_name, body: { settings:  {"index.requests.cache.enable": true }}
    end
  end
end


