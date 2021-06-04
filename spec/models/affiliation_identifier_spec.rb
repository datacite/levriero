require "rails_helper"

describe AffiliationIdentifier, type: :model, vcr: true do
  context "import affiliation_identifiers" do
    let(:from_date) { "2019-07-13" }
    let(:until_date) { "2019-07-19" }

    it "import_by_month" do
      response = AffiliationIdentifier.import_by_month(from_date: from_date,
                                                       until_date: until_date)
      expect(response).to eq("Queued import for DOIs created from 2019-07-01 until 2019-07-31.")
    end

    it "import zero" do
      from_date = "2019-07-01"
      until_date = "2019-07-01"
      response = AffiliationIdentifier.import(from_date: from_date,
                                              until_date: until_date)
      expect(response).to eq(0)
    end

    it "import" do
      until_date = "2019-07-19"
      response = AffiliationIdentifier.import(from_date: from_date,
                                              until_date: until_date)
      expect(response).to eq(0)
    end

    it "fetch ror metadata" do
      id = "https://ror.org/02catss52"
      response = AffiliationIdentifier.get_ror_metadata(id)
      expect(response["@id"]).to eq("https://ror.org/02catss52")
      expect(response["@type"]).to eq("Organization")
      expect(response["name"]).to eq("European Bioinformatics Institute")
      expect(response["location"]).to eq("addressCountry" => "United Kingdom",
                                         "type" => "postalAddress")
    end

    # it "push_item" do
    #   doi = "10.14454/cne7-ar31"
    #   attributes = AffiliationIdentifier.get_datacite_json(doi)
    #   response = AffiliationIdentifier.push_item({ "id" => doi, "type" => "dois", "attributes" => attributes })
    #   expect(response).to eq(2)
    # end
  end
end
