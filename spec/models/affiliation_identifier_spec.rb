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
      it "pushes data to the Event Data service" do
        # Mock a successful result from the Event Data service
        successful_result = double("result", body: { "data" => [{ "attributes" => {} }] })

        allow(Maremma).to receive(:post).and_return(successful_result)

        result = AffiliationIdentifier.new.push_data(successful_result)
        expect(result).to eq(1)
      end

      it "handles errors from the Event Data service" do
        # Mock an error result from the Event Data service
        error_result = double("result", body: { "errors" => "Error message" })

        allow(Maremma).to receive(:post).and_return(error_result)

        result = AffiliationIdentifier.new.push_data(error_result)
        expect(result).to eq("Error message")
      end
    end

    describe ".push_item" do
      let(:item) do
        {
          "attributes" => {
            "doi" => "10.1234/example-doi",
            "relatedIdentifiers" => [{ "relatedIdentifierType" => "IsSupplementTo", "relatedIdentifier" => "10.5678/some-related-doi" }],
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
  
      context "when STAFF_ADMIN_TOKEN is present" do
        before do
          allow(ENV).to receive(:[]).with("STAFF_ADMIN_TOKEN").and_return("example_admin_token")
          allow(AffiliationIdentifier).to receive(:cached_datacite_response).and_return({})
          allow(AffiliationIdentifier).to receive(:cached_ror_response).and_return({})
          allow(ENV).to receive(:[]).with("LAGOTTINO_URL").and_return("https://fake.lagattino.com")
          allow(ENV).to receive(:[]).with("DATACITE_AFFILIATION_SOURCE_TOKEN").and_return("DATACITE_AFFILIATION_SOURCE_TOKEN")
          allow(Rails.logger).to receive(:info)
        end
  
        it "pushes affiliation identifiers to the Event Data service" do
          allow(Maremma).to receive(:post).and_return(OpenStruct.new(status: 200, body: { "data" => { "id" => "example_id" } }))
          push_url = "https://fake.lagattino.com/events"
          expected_data = {
            "data" => {
              "type" => "events",
              "attributes" => {
                "messageAction" => "create",
                "subjId" => "https://doi.org/10.1234/example-doi",
                "objId" => "https://ror.org/02catss52",
                "relationTypeId" => "is_authored_at",
                "sourceId" => "datacite_affiliation",
                "sourceToken" => "DATACITE_AFFILIATION_SOURCE_TOKEN",
                "occurredAt" => "2023-01-05T12:00:00Z",
                "timestamp" => Time.zone.now.iso8601,
                "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
                "subj" => {},
                "obj" => {},
              },
            },
          }
  
          expect(Rails.logger).to receive(:info).with("[Event Data] https://doi.org/10.1234/example-doi is_authored_at https://ror.org/02catss52 pushed to Event Data service.")
  
          stub_request(:post, push_url).
            with(
              body: expected_data.to_json,
              headers: {
                "Authorization" => "Bearer example_admin_token",
                "Content-Type" => "application/vnd.api+json",
                "Accept" => "application/vnd.api+json; version=2",
              },
            ).
            to_return(status: 200, body: { "data" => { "id" => "example_id" } }.to_json, headers: {})
  
          AffiliationIdentifier.push_item(item)
        end
  
        it "skips pushing if STAFF_ADMIN_TOKEN is not present" do
          allow(ENV).to receive(:[]).with("STAFF_ADMIN_TOKEN").and_return(nil)
          expect(Maremma).not_to receive(:post)
  
          AffiliationIdentifier.push_item(item)
        end

        it "returns 409 for already pushed events" do
          allow(Maremma).to receive(:post).and_return(OpenStruct.new(status: 409, body: { "data" => { "id" => "example_id" } }))
          push_url = "https://fake.lagattino.com/events"
          expected_data = {
            "data" => {
              "type" => "events",
              "attributes" => {
                "messageAction" => "create",
                "subjId" => "https://doi.org/10.1234/example-doi",
                "objId" => "https://ror.org/02catss52",
                "relationTypeId" => "is_authored_at",
                "sourceId" => "datacite_affiliation",
                "sourceToken" => "DATACITE_AFFILIATION_SOURCE_TOKEN",
                "occurredAt" => "2023-01-05T12:00:00Z",
                "timestamp" => Time.zone.now.iso8601,
                "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
                "subj" => {},
                "obj" => {},
              },
            },
          }
  
          expect(Rails.logger).to receive(:info).with("[Event Data] https://doi.org/10.1234/example-doi is_authored_at https://ror.org/02catss52 already pushed to Event Data service.")
  
          stub_request(:post, push_url).
            with(
              body: expected_data.to_json,
              headers: {
                "Authorization" => "Bearer example_admin_token",
                "Content-Type" => "application/vnd.api+json",
                "Accept" => "application/vnd.api+json; version=2",
              },
            ).
            to_return(status: 200, body: { "data" => { "id" => "example_id" } }.to_json, headers: {})
  
          AffiliationIdentifier.push_item(item)
        end

        it "returns 500 when there is error while pushing an event" do
          allow(Maremma).to receive(:post).and_return(OpenStruct.new(status: 500, body: { "errors" =>  "An error occurred during the put request." }))
          allow(Rails.logger).to receive(:error)

          push_url = "https://fake.lagattino.com/events"
          expected_data = {
            "data" => {
              "type" => "events",
              "attributes" => {
                "messageAction" => "create",
                "subjId" => "https://doi.org/10.1234/example-doi",
                "objId" => "https://ror.org/02catss52",
                "relationTypeId" => "is_authored_at",
                "sourceId" => "datacite_affiliation",
                "sourceToken" => "DATACITE_AFFILIATION_SOURCE_TOKEN",
                "occurredAt" => "2023-01-05T12:00:00Z",
                "timestamp" => Time.zone.now.iso8601,
                "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
                "subj" => {},
                "obj" => {},
              },
            },
          }
  
          expect(Rails.logger).to receive(:error).with("[Event Data] https://doi.org/10.1234/example-doi is_authored_at https://ror.org/02catss52 had an error: An error occurred during the put request.")
  
          stub_request(:post, push_url).
            with(
              body: expected_data.to_json,
              headers: {
                "Authorization" => "Bearer example_admin_token",
                "Content-Type" => "application/vnd.api+json",
                "Accept" => "application/vnd.api+json; version=2",
              },
            ).
            to_return(status: 200, body: { "data" => { "id" => "example_id" } }.to_json, headers: {})
  
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
