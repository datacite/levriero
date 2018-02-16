class UniquenessValidator < ActiveModel::Validator
  

    def validate(record)

      result = ""
      if record.is_a?(Client)
        result = Client.find_by_id record.symbol
      elsif  record.is_a?(Provider) 
        result = Provider.find_by_id record.symbol
      else
        record.errors.add(:symbol, "Wrong Object passed") 
      end

      if  result.respond_to?(:symbol)
        record.errors.add(:symbol, "This ID has already been taken")
        throw(:abort, record)        
      end
    end
  end
  