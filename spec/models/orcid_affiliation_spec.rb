require "rails_helper"

describe OrcidAffiliation, type: :model, vcr: true do
  context "import orcid_affiliations" do
    let(:from_date) { "2019-07-13" }
    let(:until_date) { "2019-07-19" }

    it "import_by_month" do
      response = OrcidAffiliation.import_by_month(from_date: from_date, until_date: until_date)
      expect(response).to eq("Queued import for DOIs created from 2019-07-01 until 2019-07-31.")
    end

    it "import zero" do
      from_date = "2019-07-01"
      until_date = "2019-07-01"
      response = OrcidAffiliation.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(0)
    end

    it "import" do
      until_date = "2019-07-31"
      response = OrcidAffiliation.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(0)
    end

    # it "push_item" do
    #   doi = "10.14454/cne7-ar31"
    #   attributes = OrcidAffiliation.get_datacite_json(doi)
    #   response = OrcidAffiliation.push_item({ "id" => doi, "type" => "dois", "attributes" => attributes })
    #   expect(response).to eq(2)
    # end
  end
end
