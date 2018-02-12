class SymbolValidator < ActiveModel::Validator

    # def validate_each(record, attribute, value)

    #   if record.is_a?(Client)
    #     result = Client.find_each.select { |client| client.symbol === value }
    #   elsif  record.is_a?(Provider) 
    #     result = Provider.find_each.select { |provider| provider.symbol === value }
    #   else
    #     record.errors.add(attribute, "Wrong Object passed") 
    #     result = ["422","422"]
    #  end

    #   unless  result.length == 0 
    #     record.errors.add(attribute, "This ID has already been taken") 
    #   end
    # end
    def validate(record)

      if record.is_a?(Client)
        # result = Client.find_each.select { |client| client.symbol === record.symbol }
        result = Client.query_filter_by :symbol, record.symbol

      elsif  record.is_a?(Provider) 
        # result = Provider.find_each.select { |provider| provider.symbol === record.symbol.downcase }
        result = Provider.query_filter_by :symbol, record.symbol
      else
        record.errors.add(:symbol, "Wrong Object passed") 
        result = ["422","422"]
     end

      unless  result.count == 0 
        record.errors.add(:symbol, "This ID has already been taken")
        # record.errors.messages.ddd
        throw(:abort) 
      end
    end
  end
  