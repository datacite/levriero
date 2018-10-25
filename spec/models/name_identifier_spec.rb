require 'rails_helper'

describe NameIdentifier, type: :model, vcr: true do
  context "import name_identifiers" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-08-05" }

    it "import_by_month" do
      response = NameIdentifier.import_by_month(from_date: from_date, until_date: until_date)
      expect(response).to eq("Queued import for DOIs created from 2018-01-01 until 2018-08-31.")
    end

    it "import" do
      until_date = "2018-01-31"
      response = NameIdentifier.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(42)
    end
  end
end