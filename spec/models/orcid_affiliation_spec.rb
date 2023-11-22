require "rails_helper"

describe OrcidAffiliation, type: :model, vcr: true do
  context "import orcid_affiliations" do
    let(:from_date) { "2019-07-13" }
    let(:until_date) { "2019-07-19" }

    it "import_by_month" do
      response = OrcidAffiliation.import_by_month(from_date: from_date,
                                                  until_date: until_date)
      expect(response).to eq("Queued import for DOIs created from 2019-07-01 until 2019-07-31.")
    end

    it "import zero" do
      from_date = "2019-07-01"
      until_date = "2019-07-01"
      response = OrcidAffiliation.import(from_date: from_date,
                                         until_date: until_date)
      expect(response).to eq(0)
    end

    it "import" do
      until_date = "2019-07-31"
      response = OrcidAffiliation.import(from_date: from_date,
                                         until_date: until_date)
      expect(response).to eq(0)
    end

    it "source_id" do
      expect(OrcidAffiliation.new.source_id).to eq("orcid_affiliation")
    end

    it "query" do
      expect(OrcidAffiliation.new.query).to eq("creators.nameIdentifiers.nameIdentifierScheme:ORCID +creators.affiliation.affiliationIdentifierScheme:ROR")
    end

    describe ".push_data" do
      it "returns the correct number of items pushed" do
        result_body = { "data" => [{ "attributes" => {}, "sourceId" => "orcid_affiliation" }] }
        result = instance_double(Faraday::Response, body: result_body)

        allow(described_class).to receive(:cached_orcid_response).and_return({})
        allow(described_class).to receive(:cached_ror_response).and_return({})

        expect(OrcidAffiliationImportJob).to receive(:perform_later).once

        expect(described_class.new.push_data(result)).to eq(1)
      end

      it "returns errors when errors are present" do
        result_body = { "errors" => ["Error message"] }
        result = instance_double(Faraday::Response, body: result_body)

        expect(described_class.new.push_data(result)).to eq(["Error message"])
      end
    end

    describe ".get_ror_metadata" do
      it "returns metadata for a valid id" do
        id = "https://ror.org/012345678"
        expected_url = "https://api.ror.org/organizations/012345678"
        response_body = { "data" => { "name" => "Organization Name", "country" => { "country_name" => "Country" } } }

        allow(Maremma).to receive(:get).and_return(OpenStruct.new(status: 200,
                                                                  body: response_body))

        metadata = described_class.get_ror_metadata(id)

        expect(metadata).to eq({
                                 "@id" => id,
                                 "@type" => "Organization",
                                 "name" => "Organization Name",
                                 "location" => { "type" => "postalAddress", "addressCountry" => "Country" },
                               })
      end

      it "returns an empty hash for a blank id" do
        id = nil

        expect(described_class.get_ror_metadata(id)).to eq({})
      end

      it "returns an empty hash for an invalid id" do
        id = "invalid_id"
        stub_request(:get, "https://api.ror.org/organizations/invalid_id").
          to_return(status: 404)

        expect(described_class.get_ror_metadata(id)).to eq({})
      end
    end

    describe "#push_item" do
      before do
        allow(ENV).to receive(:[]).with("STAFF_ADMIN_TOKEN").and_return("example_admin_token")
        allow(ENV).to receive(:[]).with("ORCID_AFFILIATION_SOURCE_TOKEN").and_return("ORCID_AFFILIATION_SOURCE_TOKEN")
        allow(ENV).to receive(:[]).with("LAGOTTINO_URL").and_return("https://fake.lagattino.com")
        allow(ENV).to receive(:[]).with("API_URL").and_return("https://fake.api.com")
        allow(ENV).to receive(:[]).with("USER_AGENT").and_return("USER_AGENT")
        allow(ENV).to receive(:[]).with("CROSSREF_QUERY_URL").and_return("https://fake.crossrefurl.com")
        allow(ENV).to receive(:[]).with("VOLPINO_URL").and_return("https://fake.volpinoapi.com")
        allow(ENV).to receive(:[]).with("SLACK_WEBHOOK_URL").and_return("")
        allow(ENV).to receive(:[]).with("http_proxy").and_return(nil)
        allow(ENV).to receive(:[]).with("no_proxy").and_return(nil)
        allow(Rails.logger).to receive(:info)
      end

      it "push_item with valid data" do
        # Mocking a valid item with an ORCID name identifier and ROR affiliation identifier
        allow(Maremma).to receive(:post).and_return(OpenStruct.new(status: 201,
                                                                   body: { "data" => { "id" => "example_id" } }))

        item = {
          "attributes" => {
            "relatedIdentifiers" => [{ "relatedIdentifierType" => "IsSupplementTo",
                                       "relatedIdentifier" => "10.5678/some-related-doi" }],
            "creators" => [
              {
                "nameIdentifiers" => [
                  {
                    "nameIdentifierScheme" => "ORCID",
                    "nameIdentifier" => "0000-0001-2345-6789",
                  },
                ],
                "affiliation" => [
                  {
                    "affiliationIdentifierScheme" => "ROR",
                    "affiliationIdentifier" => "https://ror.org/02catss52",
                  },
                ],
              },
            ],
            "updated" => "2023-01-05T12:00:00Z",
          },
          "sourceId" => "orcid_affiliation",
        }

        expect(OrcidAffiliation).to receive(:normalize_orcid).with("0000-0001-2345-6789").and_return("https://orcid.org/0000-0001-2345-6789")
        expect(OrcidAffiliation).to receive(:normalize_ror).with("https://ror.org/02catss52").and_return("https://ror.org/normalized-ror-id")

        expect(Rails.logger).to receive(:info).with("[Event Data] https://orcid.org/0000-0001-2345-6789 is_affiliated_with https://ror.org/normalized-ror-id pushed to Event Data service.")

        response = OrcidAffiliation.push_item(item)
        expect(response).to eq(1)
      end

      it "push_item with valid already pushed data" do
        # Mocking a valid item with an ORCID name identifier and ROR affiliation identifier
        allow(Maremma).to receive(:post).and_return(OpenStruct.new(status: 409,
                                                                   body: { "data" => { "id" => "example_id" } }))

        item = {
          "attributes" => {
            "relatedIdentifiers" => [{ "relatedIdentifierType" => "IsSupplementTo",
                                       "relatedIdentifier" => "10.5678/some-related-doi" }],
            "creators" => [
              {
                "nameIdentifiers" => [
                  {
                    "nameIdentifierScheme" => "ORCID",
                    "nameIdentifier" => "0000-0001-2345-6789",
                  },
                ],
                "affiliation" => [
                  {
                    "affiliationIdentifierScheme" => "ROR",
                    "affiliationIdentifier" => "https://ror.org/02catss52",
                  },
                ],
              },
            ],
            "updated" => "2023-01-05T12:00:00Z",
          },
          "sourceId" => "orcid_affiliation",
        }

        expect(OrcidAffiliation).to receive(:normalize_orcid).with("0000-0001-2345-6789").and_return("https://orcid.org/0000-0001-2345-6789")
        expect(OrcidAffiliation).to receive(:normalize_ror).with("https://ror.org/02catss52").and_return("https://ror.org/normalized-ror-id")

        expect(Rails.logger).to receive(:info).with("[Event Data] https://orcid.org/0000-0001-2345-6789 is_affiliated_with https://ror.org/normalized-ror-id already pushed to Event Data service.")

        response = OrcidAffiliation.push_item(item)
        expect(response).to eq(1)
      end

      it "push_item with valid with error" do
        # Mocking a valid item with an ORCID name identifier and ROR affiliation identifier
        allow(Maremma).to receive(:post).and_return(OpenStruct.new(status: 500,
                                                                   body: { "errors" => "An error occurred during the put request." }))
        allow(Rails.logger).to receive(:error)

        item = {
          "attributes" => {
            "relatedIdentifiers" => [{ "relatedIdentifierType" => "IsSupplementTo",
                                       "relatedIdentifier" => "10.5678/some-related-doi" }],
            "creators" => [
              {
                "nameIdentifiers" => [
                  {
                    "nameIdentifierScheme" => "ORCID",
                    "nameIdentifier" => "0000-0001-2345-6789",
                  },
                ],
                "affiliation" => [
                  {
                    "affiliationIdentifierScheme" => "ROR",
                    "affiliationIdentifier" => "https://ror.org/02catss52",
                  },
                ],
              },
            ],
            "updated" => "2023-01-05T12:00:00Z",
          },
          "sourceId" => "orcid_affiliation",
        }

        expect(OrcidAffiliation).to receive(:normalize_orcid).with("0000-0001-2345-6789").and_return("https://orcid.org/0000-0001-2345-6789")
        expect(OrcidAffiliation).to receive(:normalize_ror).with("https://ror.org/02catss52").and_return("https://ror.org/normalized-ror-id")

        expect(Rails.logger).to receive(:error).with("[Event Data] https://orcid.org/0000-0001-2345-6789 is_affiliated_with https://ror.org/normalized-ror-id had an error: An error occurred during the put request.")

        response = OrcidAffiliation.push_item(item)
        expect(response).to eq(1)
      end

      it "push_item with missing ORCID data" do
        # Mocking an item with missing ORCID data
        allow(Maremma).to receive(:post).and_return(OpenStruct.new(status: 201,
                                                                   body: { "data" => { "id" => "example_id" } }))
        item = {
          "attributes" => {
            "relatedIdentifiers" => [{ "relatedIdentifierType" => "IsSupplementTo",
                                       "relatedIdentifier" => "10.5678/some-related-doi" }],
            "creators" => [
              {
                "affiliation" => [
                  {
                    "affiliationIdentifierScheme" => "ROR",
                    "affiliationIdentifier" => "https://ror.org/02catss52",
                  },
                ],
              },
            ],
            "updated" => "2023-01-05T12:00:00Z",
          },
          "sourceId" => "orcid_affiliation",
        }

        response = OrcidAffiliation.push_item(item)
        expect(response).to eq(nil)
      end

      it "push_item with related identifier type to skip" do
        # Mocking an item with a related identifier type to skip
        item = {
          "attributes" => {
            "relatedIdentifiers" => [{ "relatedIdentifierType" => "IsIdenticalTo",
                                       "relatedIdentifier" => "10.5678/some-related-doi" }],
            "creators" => [
              {
                "nameIdentifiers" => [
                  {
                    "nameIdentifierScheme" => "ORCID",
                    "nameIdentifier" => "0000-0001-2345-6789",
                  },
                ],
                "affiliation" => [
                  {
                    "affiliationIdentifierScheme" => "ROR",
                    "affiliationIdentifier" => "https://ror.org/02catss52",
                  },
                ],
              },
            ],
            "updated" => "2023-01-05T12:00:00Z",
          },
          "sourceId" => "orcid_affiliation",
        }

        response = OrcidAffiliation.push_item(item)
        expect(response).to eq(nil)
      end
    end
  end
end
