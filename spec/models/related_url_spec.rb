require 'rails_helper'

describe RelatedUrl, type: :model, vcr: true do
  context "import related_urls" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-08-05" }

    it "import_by_month" do
      response = RelatedUrl.import_by_month(from_date: from_date, until_date: until_date)
      expect(response).to eq("Queued import for DOIs updated from 2018-01-01 until 2018-08-31.")
    end

    it "import" do
      until_date = "2018-01-31"
      response = RelatedUrl.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(29)
    end
  end
end
