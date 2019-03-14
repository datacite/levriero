require 'rails_helper'

describe RelatedUrl, type: :model, vcr: true do
  context "instance methods" do
    subject { RelatedUrl.new }

    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-08-05" }

    it "get_query_url" do
      response = subject.get_query_url(from_date: from_date, until_date: until_date)
      expect(response).to eq("https://api.test.datacite.org//dois?query=relatedIdentifiers.relatedIdentifierType%3AURL+AND+updated%3A%5B2018-01-04T00%3A00%3A00Z+TO+2018-08-05T23%3A59%3A59Z%5D&page%5Bnumber%5D=1&page%5Bsize%5D=1000")
    end

    it "get_total" do
      response = subject.get_total(from_date: from_date, until_date: until_date)
      expect(response).to eq(109)
    end
  end

  context "class methods" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-08-05" }

    it "import_by_month" do
      response = RelatedUrl.import_by_month(from_date: from_date, until_date: until_date)
      expect(response).to eq("Queued import for DOIs updated from 2018-01-01 until 2018-08-31.")
    end

    it "import" do
      until_date = "2018-01-31"
      response = RelatedUrl.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(14)
    end

    it "push_item" do
      doi = "10.22002/d1.646"
      attributes = RelatedUrl.get_datacite_json(doi)
      response = RelatedUrl.push_item({ "id" => doi, "type" => "dois", "attributes" => attributes })
      expect(response).to eq(1)
    end
  end
end
