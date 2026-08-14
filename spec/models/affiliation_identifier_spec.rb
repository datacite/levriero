require "rails_helper"

describe AffiliationIdentifier, type: :model, vcr: true do
  context "import affiliation_identifiers" do
    let(:from_date) { "2019-07-13" }
    let(:until_date) { "2019-07-19" }

    describe ".import_by_month" do
      it "queues jobs for each month between from_date and until_date" do
        response = AffiliationIdentifier.import_by_month(from_date: from_date, until_date: until_date)
        expect(response).to eq("Queued import for DOIs created from 2019-07-01 until 2019-07-31.")
      end
    end

    describe ".import" do
      it "queues jobs for DOIs created within the specified date range" do
        until_date = "2019-07-19"
        response = AffiliationIdentifier.import(from_date: from_date, until_date: until_date)
        expect(response).to eq(0) # You may need to update the expected value based on your implementation
      end
    end

    describe "#source_id" do
      it "returns 'datacite_affiliation' as the source_id" do
        affiliation_identifier = AffiliationIdentifier.new
        expect(affiliation_identifier.source_id).to eq("datacite_affiliation")
      end
    end

    describe "#query" do
      it "returns the correct query string" do
        affiliation_identifier = AffiliationIdentifier.new
        expect(affiliation_identifier.query).to eq("creators.affiliation.affiliationIdentifierScheme:ROR")
      end
    end

    describe "#push_data" do
      it "pushes data to the events queue" do
        successful_result = double("result", body: { "data" => [{ "attributes" => {} }] })
        result = AffiliationIdentifier.new.push_data(successful_result)
        expect(result).to eq(1)
      end
    end

    describe ".push_item" do
      let(:item) do
        {
          "attributes" => {
            "doi" => "10.1234/example-doi",
            "relatedIdentifiers" => [{ "relatedIdentifierType" => "IsSupplementTo",
                                       "relatedIdentifier" => "10.5678/some-related-doi" }],
            "creators" => [
              {
                "affiliation" => [
                  {
                    "affiliationIdentifierScheme" => "ROR",
                    "affiliationIdentifier" => "https://ror.org/02catss52",
                  },
                  {
                    "affiliationIdentifierScheme" => "OtherScheme",
                    "affiliationIdentifier" => "https://other.org/12345",
                  },
                ],
              },
            ],
            "updated" => "2023-01-05T12:00:00Z",
          },
          "sourceId" => "datacite_affiliation",
        }
      end

      context "when can add to events queue" do
        before do
          allow(AffiliationIdentifier).to receive(:cached_datacite_response).and_return({})
          allow(AffiliationIdentifier).to receive(:cached_ror_response).and_return({})
          allow(ENV).to receive(:[]).with("DATACITE_AFFILIATION_SOURCE_TOKEN").and_return("DATACITE_AFFILIATION_SOURCE_TOKEN")
          allow(Rails.logger).to receive(:info)
          allow(AffiliationIdentifier).to receive(:send_event_import_message).and_return(nil)
        end

        it "pushes affiliation identifiers to the events queue" do
          expect(Rails.logger).to receive(:info).with("[Event Data] https://doi.org/10.1234/example-doi is_authored_at https://ror.org/02catss52 sent to the events queue.")
          expect(AffiliationIdentifier).to receive(:send_event_import_message).once

          AffiliationIdentifier.push_item(item)
        end
      end
    end

    describe ".get_ror_metadata" do
      it "returns ROR metadata for a given ROR ID" do
        id = "https://ror.org/02catss52"
        response = AffiliationIdentifier.get_ror_metadata(id)
        expect(response["@id"]).to eq("https://ror.org/02catss52")
        expect(response["@type"]).to eq("Organization")
        expect(response["name"]).to eq("European Bioinformatics Institute")
        expect(response["location"]).to eq("addressCountry" => "United Kingdom", "type" => "postalAddress")
      end

      it "returns an empty hash for a blank ROR ID" do
        id = nil
        response = AffiliationIdentifier.get_ror_metadata(id)
        expect(response).to eq({})
      end
    end
  end
end
