require 'rails_helper'

describe FunderIdentifier, type: :model, vcr: true do
  context "import funder_identifiers" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-08-05" }

    it "import_by_month" do
      response = FunderIdentifier.import_by_month(from_date: from_date, until_date: until_date)
      expect(response).to eq("Queued import for DOIs updated from 2018-01-01 until 2018-08-31.")
    end

    it "import" do
      until_date = "2018-01-31"
      response = FunderIdentifier.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(31)
    end

    it "fetch funder metadata" do
      id = "https://doi.org/10.13039/100011326"
      response = FunderIdentifier.get_funder_metadata(id)
      expect(response["id"]).to eq("https://doi.org/10.13039/100011326")
      expect(response["type"]).to eq("funder")
      expect(response["name"]).to eq("London School of Economics and Political Science")
      expect(response["alternate-name"]).to eq(["London School of Economics & Political Science", "LSE"])
    end
  end
end