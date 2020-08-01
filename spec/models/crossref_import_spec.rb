require 'rails_helper'

describe CrossrefImport, type: :model, vcr: true do
  context "instance methods" do
    subject { CrossrefImport.new }

    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-01-04" }

    it "get_query_url" do
      response = subject.get_query_url(from_date: from_date, until_date: until_date, rows: 0)
      expect(response).to eq("https://api.crossref.org/works?filter=from-created-date%3A2018-01-04%2Cuntil-created-date%3A2018-01-04&mailto=info%40datacite.org&rows=0")
    end

    it "get_query_url with cursor" do
      response = subject.get_query_url(from_date: from_date, until_date: until_date, cursor: "AoJ+6ten1u4CPwRodHRwOi8vZHguZG9pLm9yZy8xMC4zMzkwL3YxMDA3MDM2OQ==")
      expect(response).to eq("https://api.crossref.org/works?filter=from-created-date%3A2018-01-04%2Cuntil-created-date%3A2018-01-04&mailto=info%40datacite.org&cursor=AoJ%2B6ten1u4CPwRodHRwOi8vZHguZG9pLm9yZy8xMC4zMzkwL3YxMDA3MDM2OQ%3D%3D")
    end

    it "get_total" do
      response = subject.get_total(from_date: from_date, until_date: until_date)
      expect(response).to eq(17905)
    end

    it "get_total in 2013" do
      response = subject.get_total(from_date: "2013-10-01", until_date: "2013-10-31")
      expect(response).to eq(663513)
    end
  end
  
  context "import crossref_import" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-01-04" }

    it "import_by_month" do
      response = CrossrefImport.import_by_month(from_date: "2013-10-01", until_date: "2013-10-31")
      expect(response).to eq("Queued import for DOIs created from 2013-10-01 until 2013-10-31.")
    end

    it "import" do
      response = CrossrefImport.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(17905)
    end

    it "push_item" do 
      item = { 
        "DOI" => "10.1021/jp036075h",
        "created" => { "date-time" => "2015-10-05T10:01:19Z" }
      }
      response = CrossrefImport.push_item(item)
      expect(response).to eq(1)
    end

    it "push_related_items" do 
      item = { 
        "DOI" => "10.1016/s0191-6599(01)00017-1",
        "reference" => [{ "DOI" => "10.2307/1847110" }],
        "created" => { "date-time" => "2002-07-25T17:19:59Z" }
      }
      pid = "https://doi.org/10.1016/s0191-6599(01)00017-1"
      response = CrossrefImport.push_related_items(item: item, pid: pid).first
      expect(response["subj_id"]).to eq(pid)
      expect(response["relation_type_id"]).to eq("cites")
    end

    it "push_funding_items" do 
      item = { 
        "DOI" => "10.1039/c8cc06410e",
        "funder" => [{ "DOI" => "https://doi.org/10.13039/501100001659" }],
        "created" => { "date-time" => "2015-10-05T10:01:19Z" }
      }
      pid = "https://doi.org/10.1039/c8cc06410e"
      response = CrossrefImport.push_funding_items(item: item, pid: pid).first
      expect(response["subj_id"]).to eq(pid)
      expect(response["relation_type_id"]).to eq("is_funded_by")
    end

    it "push_orcid_items" do 
      item = { 
        "DOI" => "10.1039/c5ee02393a",
        "author" => [{ "ORCID" => "http://orcid.org/0000-0001-5423-6818" }],
        "created" => { "date-time" => "2015-10-05T10:01:19Z" }
      }
      pid = "https://doi.org/10.1039/c5ee02393a"
      response = CrossrefImport.push_orcid_items(item: item, pid: pid).first
      expect(response["subj_id"]).to eq(pid)
      expect(response["relation_type_id"]).to eq("is_authored_by")
    end

    it "push_import_item" do
      item = { 
        "DOI" => "10.1021/jp036075h",
        "created" => { "date-time" => "2015-10-05T10:01:19Z" }
      }
      pid = "https://doi.org/10.1021/jp036075h"
      response = CrossrefImport.push_import_item(item: item, pid: pid).first
      expect(response["subj_id"]).to eq(pid)
      expect(response["relation_type_id"]).to be_nil
    end
  end
end
