require 'rails_helper'

describe FunderIdentifier, type: :model, vcr: true do
  context "import funder_identifiers" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2019-06-30" }

    it "import_by_month" do
      response = FunderIdentifier.import_by_month(from_date: from_date, until_date: until_date)
      expect(response).to eq("Queued import for DOIs created from 2018-01-01 until 2019-06-30.")
    end

    it "import" do
      until_date = "2019-06-30"
      response = FunderIdentifier.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(31)
    end

    it "fetch funder metadata" do
      id = "https://doi.org/10.13039/100011326"
      response = FunderIdentifier.get_funder_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.13039/100011326")
      expect(response["@type"]).to eq("Funder")
      expect(response["name"]).to eq("London School of Economics and Political Science")
      expect(response["alternateName"]).to eq(["London School of Economics & Political Science", "The London School of Economics and Political Science", "LSE"])
      expect(response["dateModified"]).to eq("2018-07-11T00:00:00Z")
    end

    it "push_item" do
      doi = "10.15125/bath-00708"
      attributes = FunderIdentifier.get_datacite_json(doi)
      response = FunderIdentifier.push_item({ "id" => doi, "type" => "dois", "attributes" => attributes })
      expect(response).to eq(1)
    end
  end
end