require "rails_helper"

describe RelatedUrl, type: :model, vcr: true do
  context "instance methods" do
    subject { RelatedUrl.new }

    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-08-05" }

    it "get_query_url" do
      response = subject.get_query_url(from_date: from_date,
                                       until_date: until_date)
      expect(response).to eq("https://api.stage.datacite.org/dois?query=relatedIdentifiers.relatedIdentifierType%3AURL+AND+updated%3A%5B2018-01-04T00%3A00%3A00Z+TO+2018-08-05T23%3A59%3A59Z%5D&resource-type-id=&page%5Bnumber%5D=1&page%5Bsize%5D=1000&exclude_registration_agencies=true&affiliation=true")
    end

    it "get_total" do
      response = subject.get_total(from_date: from_date, until_date: until_date)
      expect(response).to eq(19)
    end
  end

  context "class methods" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-08-05" }

    it "import_by_month" do
      response = RelatedUrl.import_by_month(from_date: from_date,
                                            until_date: until_date)
      expect(response).to eq("Queued import for DOIs updated from 2018-01-01 until 2018-08-31.")
    end

    it "import" do
      until_date = "2018-12-31"
      response = RelatedUrl.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(19)
    end

    describe "push_item" do
      before(:each) do
        allow(ENV).to(receive(:[]).with("DATACITE_URL_SOURCE_TOKEN").and_return("DATACITE_URL_SOURCE_TOKEN"))
        allow(Base).to(receive(:cached_datacite_response).and_return({ "foo" => "bar" }))
        allow(RelatedUrl).to(receive(:send_event_import_message).and_return(nil))
        allow(Time).to(receive_message_chain(:zone, :now, :iso8601).and_return("2023-11-15T12:17:47Z"))
        allow(RelatedUrl).to(receive(:send_event_import_message).and_return(nil))
      end

      it "returns nil if the doi is blank" do
        expect(RelatedUrl.push_item("doi" => nil)).to(eq(nil))
      end

      it "sends to the events queue for those related identifiers with type 'URL'" do
        item = {
          "attributes" => {
            "doi" => "https://doi.org/10.0001/foo.bar",
            "updated" => "2023-11-15",
            "relatedIdentifiers" => [
              {
                "relatedIdentifierType" => "URL",
                "relatedIdentifier" => "https://doi.org/10.0001/example.one",
                "relationType" => "example-one",
              },
              {
                "relatedIdentifierType" => "DOI",
                "relatedIdentifier" => "https://doi.org/10.0001/example.two",
                "relationType" => "example-two",
              },
              {
                "relatedIdentifierType" => "URL",
                "relatedIdentifier" => "https://doi.org/10.0001/example.three",
                "relationType" => "example-three",
              },
            ],
          },
        }

        expect(RelatedUrl.push_item(item)).to(eq(2))
        expect(RelatedUrl).to(have_received(:send_event_import_message).twice)
      end

      it "passes the expected values to events queue" do
        item = {
          "attributes" => {
            "doi" => "https://doi.org/10.0001/foo.bar",
            "updated" => "2023-11-15",
            "relatedIdentifiers" => [
              {
                "relatedIdentifierType" => "URL",
                "relatedIdentifier" => "https://doi.org/10.0001/example.one",
                "relationType" => "example-one",
              },
            ],
          },
        }

        json_data = {
          "data" => {
            "type" => "events",
            "attributes" => {
              "messageAction" => "create",
              "subjId" => "https://doi.org/10.0001/foo.bar",
              "objId" => "https://doi.org/10.0001/example.one",
              "relationTypeId" => "example-one",
              "sourceId" => "datacite-url",
              "sourceToken" => "DATACITE_URL_SOURCE_TOKEN",
              "occurredAt" => "2023-11-15",
              "timestamp" => "2023-11-15T12:17:47Z",
              "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
              "subj" => { "foo" => "bar" },
              "obj" => {},
            },
          },
        }

        expect(RelatedUrl.push_item(item)).to(eq(1))
        expect(RelatedUrl).to(have_received(:send_event_import_message).with(json_data).once)
      end
    end
  end
end
