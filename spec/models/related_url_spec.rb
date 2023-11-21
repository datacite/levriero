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
      it "returns nil if the doi is blank" do
        expect(RelatedUrl.push_item("doi" => nil)).to(eq(nil))
      end

      describe "when STAFF_ADMIN_TOKEN" do
        before(:each) do
          allow(ENV).to(receive(:[]).with("STAFF_ADMIN_TOKEN").and_return("STAFF_ADMIN_TOKEN"))
          allow(ENV).to(receive(:[]).with("LAGOTTINO_URL").and_return("https://fake.lagattino.com"))
          allow(ENV).to(receive(:[]).with("DATACITE_URL_SOURCE_TOKEN").and_return("DATACITE_URL_SOURCE_TOKEN"))
          allow(Base).to(receive(:cached_datacite_response).and_return({"foo" => "bar"}))
          allow(Maremma).to(receive(:post).and_return(OpenStruct.new(status: 200)))
          allow(Time).to(receive_message_chain(:zone, :now, :iso8601).and_return("2023-11-15T12:17:47Z"))
        end

        describe "is valid" do
          it "makes request to lagottino for those related identifiers with type 'URL'" do
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

            expect(Maremma).to(have_received(:post).twice)
          end

          it "passes the expected values to lagottino" do
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
            }.to_json

            expect(RelatedUrl.push_item(item)).to(eq(1))

            expect(Maremma).to(have_received(:post).with(
                                 "https://fake.lagattino.com/events",
                                 data: json_data,
                                 bearer: "STAFF_ADMIN_TOKEN",
                                 content_type: "application/vnd.api+json",
                                 accept: "application/vnd.api+json; version=2",
                               ))
          end
        end

        describe "is invalid" do
          it "will not make request to lagottino" do
            allow(ENV).to(receive(:[]).with("STAFF_ADMIN_TOKEN").and_return(nil))

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

            expect(Maremma).not_to(have_received(:post))
          end
        end
      end
    end
  end
end
