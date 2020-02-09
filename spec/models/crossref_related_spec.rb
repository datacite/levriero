require 'rails_helper'

describe CrossrefRelated, type: :model, vcr: true do
  context "instance methods" do
    subject { CrossrefRelated.new }

    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-01-04" }

    it "get_query_url" do
      response = subject.get_query_url(from_date: from_date, until_date: until_date, rows: 0)
      expect(response).to eq("https://api.crossref.org/works?filter=reference-visibility%3Aopen%2Chas-references%3Atrue%2Cfrom-created-date%3A2018-01-04%2Cuntil-created-date%3A2018-01-04&mailto=info%40datacite.org&rows=0")
    end

    it "get_query_url with cursor" do
      response = subject.get_query_url(from_date: from_date, until_date: until_date, cursor: "AoJ+6ten1u4CPwRodHRwOi8vZHguZG9pLm9yZy8xMC4zMzkwL3YxMDA3MDM2OQ==")
      expect(response).to eq("https://api.crossref.org/works?filter=reference-visibility%3Aopen%2Chas-references%3Atrue%2Cfrom-created-date%3A2018-01-04%2Cuntil-created-date%3A2018-01-04&mailto=info%40datacite.org&cursor=AoJ%2B6ten1u4CPwRodHRwOi8vZHguZG9pLm9yZy8xMC4zMzkwL3YxMDA3MDM2OQ%3D%3D")
    end

    it "get_total" do
      response = subject.get_total(from_date: from_date, until_date: until_date)
      expect(response).to eq(5333)
    end

    it "get_total in 2013" do
      response = subject.get_total(from_date: "2013-10-01", until_date: "2013-10-31")
      expect(response).to eq(163179)
    end
  end
  
  context "import crossref_related" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-01-04" }

    it "import_by_month" do
      response = CrossrefRelated.import_by_month(from_date: "2013-10-01", until_date: "2013-10-31")
      expect(response).to eq("Queued import for DOIs created from 2013-10-01 until 2013-10-31.")
    end

    it "import" do
      response = CrossrefRelated.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(5333)
    end

    it "push_item" do 
      item = { 
        "DOI" => "10.1016/s0191-6599(01)00017-1",
        "reference" => [{ "DOI" => "10.2307/1847110" }],
        "created" => { "date-time" => "2002-07-25T17:19:59Z" }
      }
      response = CrossrefRelated.push_item(item)
      expect(response).to eq(1)
    end
  end
end
