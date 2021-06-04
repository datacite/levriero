class UniquenessValidator < ActiveModel::Validator
  def validate(record)
    result = record.class.find_by(id: record.symbol)
    if result.present?
      record.errors.add(:symbol,
                        "This ID has already been taken")
    end
  end
end
