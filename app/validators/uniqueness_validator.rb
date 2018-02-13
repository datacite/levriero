class UniquenessValidator < ActiveModel::Validator
  

    def validate(record)

      if record.is_a?(Client)
        result = Client.query_filter_by :symbol, record.symbol.downcase
      elsif  record.is_a?(Provider) 
        result = Provider.query_filter_by :symbol, record.symbol.downcase
      else
        record.errors.add(:symbol, "Wrong Object passed") 
        result = ["422","422"]
     end

      unless  result.count == 0 
        record.errors.add(:symbol, "This ID has already been taken")
        throw(:abort, record)        
      end
    end
  end
  