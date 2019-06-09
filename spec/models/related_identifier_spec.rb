require 'rails_helper'

describe RelatedIdentifier, type: :model, vcr: true do
  context "import related_identifiers" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-08-05" }

    it "import_by_month" do
      response = RelatedIdentifier.import_by_month(from_date: from_date, until_date: until_date)
      expect(response).to eq("Queued import for DOIs created from 2018-01-01 until 2018-08-31.")
    end

    it "import" do
      until_date = "2018-01-31"
      response = RelatedIdentifier.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(97)
    end

    it "push_item" do
      doi = "10.5061/dryad.j86rt6b"
      attributes = RelatedIdentifier.get_datacite_json(doi)
      response = RelatedIdentifier.push_item({ "id" => doi, "type" => "dois", "attributes" => attributes })
      expect(response).to eq(8)
    end
  end
end
