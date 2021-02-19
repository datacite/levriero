require 'rails_helper'

describe RelatedPmid, type: :model, vcr: true do
  context "instance methods" do
    subject { RelatedPmid.new }

    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2020-08-05" }

    it "get_query_url" do
      response = subject.get_query_url(from_date: from_date, until_date: until_date)
      puts response
      expect(response).to eq("https://api.stage.datacite.org/dois?query=relatedIdentifiers.relatedIdentifierType%3APMID+AND+updated%3A%5B2018-01-04T00%3A00%3A00Z+TO+2020-08-05T23%3A59%3A59Z%5D&resource-type-id=&page%5Bnumber%5D=1&page%5Bsize%5D=1000&exclude_registration_agencies=true&affiliation=true")
    end

    it "get_total" do
      response = subject.get_total(from_date: from_date, until_date: until_date)
      expect(response).to eq(594)
    end
  end

  context "class methods" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2020-08-05" }

    it "import_by_month" do
      response = RelatedPmid.import_by_month(from_date: from_date, until_date: until_date)
      expect(response).to eq("Queued import for DOIs updated from 2018-01-01 until 2020-08-31.")
    end

    it "import" do
      until_date = "2020-12-31"
      response = RelatedPmid.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(594)
    end

    it "push_item" do
      doi = "10.7272/42z6-cf76"
      attributes = RelatedPmid.get_datacite_json(doi)
      response = RelatedPmid.push_item({ "id" => doi, "type" => "dois", "attributes" => attributes })
      expect(response).to eq(1)
    end
  end
end
