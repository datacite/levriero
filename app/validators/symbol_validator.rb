class SymbolValidator < ActiveModel::EachValidator
    # require 'elasticsearch/dsl'
    # include Elasticsearch::DSL

    def validate_each(record, attribute, value)

      result = Provider.query_filter_by(attribute, value)
  
      unless  result.length == 0 
        record.errors.add(attribute, "This ID has already been taken") 
      end
    end
  end
  