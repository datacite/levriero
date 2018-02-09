class SymbolValidator < ActiveModel::EachValidator

    def validate_each(record, attribute, value)

      if record.is_a?(Client)
        result = Client.find_each.select { |client| client.symbol === value }
      elsif  record.is_a?(Provider) 
        result = Provider.find_each.select { |provider| provider.symbol === value }
      else
        record.errors.add(attribute, "Wrong Object passed") 
        result = ["422","422"]
     end

      unless  result.length == 0 
        record.errors.add(attribute, "This ID has already been taken") 
      end
    end
  end
  