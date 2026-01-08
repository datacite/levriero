require "rails_helper"

describe NameIdentifier, type: :model, vcr: true do
  context "import name_identifiers" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2018-08-05" }

    it "import_by_month" do
      response = NameIdentifier.import_by_month(from_date: from_date,
                                                until_date: until_date)
      expect(response).to eq("Queued import for DOIs created from 2018-01-01 until 2018-08-31.")
    end

    it "import" do
      until_date = "2018-01-31"
      response = NameIdentifier.import(from_date: from_date,
                                       until_date: until_date)
      expect(response).to eq(22)
    end

    describe "#push_item" do
      let(:staff_profiles_admin_token) { "STAFF_PROFILES_ADMIN_TOKEN" }

      let(:lagottino_json) do
        {
          "data" => {
            "type" => "events",
            "attributes" => {
              "messageAction" => "create",
              "subjId" => "https://doi.org/10.0001/foo.bar",
              "objId" => "https://orcid.org/0000-0000-0000-0000",
              "relationTypeId" => "is-authored-by",
              "sourceId" => "datacite-orcid-auto-update",
              "sourceToken" => "DATACITE_ORCID_AUTO_UPDATE_SOURCE_TOKEN",
              "occurredAt" => "2023-11-15",
              "timestamp" => "2023-11-15T12:17:47Z",
              "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
              "subj" => { "foo" => "bar" },
              "obj" => { "bar" => "foo" },
            },
          },
        }.to_json
      end

      let(:volpino_json) do
        {
          "claim" => {
            "doi" => "10.0001/foo.bar",
            "orcid" => "0000-0000-0000-0000",
            "source_id" => "orcid_update",
            "claim_action" => "create",
          },
        }.to_json
      end

      before(:each) do
        allow(ENV).to receive(:[]).and_call_original
        
        allow(ENV).
          to(receive(:[]).
            with("LAGOTTINO_URL").
            and_return("https://fake.lagattino.com"))

        allow(ENV).
          to(receive(:[]).
            with("DATACITE_ORCID_AUTO_UPDATE_SOURCE_TOKEN").
            and_return("DATACITE_ORCID_AUTO_UPDATE_SOURCE_TOKEN"))

        allow(ENV).
          to(receive(:[]).
            with(staff_profiles_admin_token).
            and_return(staff_profiles_admin_token))

        allow(ENV).
          to(receive(:[]).
            with("VOLPINO_URL").
            and_return("https://fake.volpino.com"))

        allow(ENV).
          to(receive(:[]).
            with("EXCLUDE_PREFIXES_FROM_ORCID_CLAIMING").
            and_return(""))
        
        allow(ENV).
          to(receive(:[]).
            with("API_URL").
            and_return("https://api.stage.datacite.org"))

        allow(ENV).
          to(receive(:[]).
            with("USER_AGENT").
            and_return("Mozilla/5.0 (compatible; Maremma/5.0.0; mailto:info@datacite.org)"))

        allow(ENV).to receive(:[]).with("no_proxy").and_return(nil)
        allow(ENV).to receive(:[]).with("NO_PROXY").and_return(nil)
        allow(ENV).to receive(:[]).with("STAFF_PROFILES_ADMIN_TOKEN").and_return("STAFF_PROFILES_ADMIN_TOKEN")
        allow(ENV).to receive(:[]).with("ORCID_API_URL").and_return("https://fake.orcidapiurl.com")
        allow(ENV).to receive(:[]).with("SSL_CERT_FILE").and_return("https://fake.orcidapiurl.com")
        allow(ENV).to receive(:[]).with("SSL_CERT_DIR").and_return("https://fake.orcidapiurl.com")
        allow(ENV).to receive(:[]).with("STAFF_ADMIN_TOKEN").and_return(nil)
        allow(ENV).to receive(:[]).with("SLACK_WEBHOOK_URL").and_return("https://fake.slackwebhookurl.com")

        allow(Base).
          to(receive(:cached_datacite_response).
          and_return("foo" => "bar"))

        allow(Base).
          to(receive(:cached_orcid_response).
          and_return("bar" => "foo"))

        allow(Maremma).
          to(receive(:post).
            with("https://fake.volpino.com/claims", anything).
            and_return(OpenStruct.new(status: 202)))

        allow(Time).
          to(receive_message_chain(:zone, :now, :iso8601).
            and_return("2023-11-15T12:17:47Z"))

        allow(NameIdentifier).to(receive(:send_event_import_message).and_return(nil))
      end

      describe "returns nil" do
        it "if the doi is blank" do
          expect(NameIdentifier.push_item("doi" => nil)).to(eq(nil))
        end

        it "if there is a related identifier type of 'IsIdenticalTo'" do
          item = {
            "attributes" => {
              "doi" => "https://doi.org/10.0001/foo.bar",
              "updated" => "2023-11-15",
              "relatedIdentifiers" => [
                { "relationType" => "IsIdenticalTo" },
              ],
              "creators" => [
                "nameIdentifiers" => [
                  {
                    "nameIdentifierScheme" => "ORCID",
                    "nameIdentifier" => "https://doi.org/10.0001/example.one",
                  },
                ],
              ],
            },
          }

          expect(NameIdentifier.push_item(item)).to(eq(nil))
        end

        it "if there is a related identifier type of 'IsPartOf'" do
          item = {
            "attributes" => {
              "doi" => "https://doi.org/10.0001/foo.bar",
              "updated" => "2023-11-15",
              "relatedIdentifiers" => [
                { "relationType" => "IsPartOf" },
              ],
              "creators" => [
                "nameIdentifiers" => [
                  {
                    "nameIdentifierScheme" => "ORCID",
                    "nameIdentifier" => "https://doi.org/10.0001/example.one",
                  },
                ],
              ],
            },
          }

          expect(NameIdentifier.push_item(item)).to(eq(nil))
        end

        it "if there is a related identifier type of 'IsPreviousVersionOf'" do
          item = {
            "attributes" => {
              "doi" => "https://doi.org/10.0001/foo.bar",
              "updated" => "2023-11-15",
              "relatedIdentifiers" => [
                { "relationType" => "IsPreviousVersionOf" },
              ],
              "creators" => [
                "nameIdentifiers" => [
                  {
                    "nameIdentifierScheme" => "ORCID",
                    "nameIdentifier" => "https://doi.org/10.0001/example.one",
                  },
                ],
              ],
            },
          }

          expect(NameIdentifier.push_item(item)).to(eq(nil))
        end

        it "if there is a related identifier type of 'IsVersionOf'" do
          item = {
            "attributes" => {
              "doi" => "https://doi.org/10.0001/foo.bar",
              "updated" => "2023-11-15",
              "relatedIdentifiers" => [
                { "relationType" => "IsVersionOf" },
              ],
              "creators" => [
                "nameIdentifiers" => [
                  {
                    "nameIdentifierScheme" => "ORCID",
                    "nameIdentifier" => "https://doi.org/10.0001/example.one",
                  },
                ],
              ],
            },
          }

          expect(NameIdentifier.push_item(item)).to(eq(nil))
        end

        it "if the DOI is in a client with client_type raidRegistry" do
          ## DOI in client with client_type raidRegistry
          doi = "10.82610/3pst-w184"
          attributes = NameIdentifier.get_datacite_json(doi, include_client: true)
          response = { "id" => doi, "type" => "dois",
                        "attributes" => attributes }

          expect(NameIdentifier.push_item(response)).to(eq(nil))
        end

        it "if there aren't any creators" do
          item = {
            "attributes" => {
              "doi" => "https://doi.org/10.0001/foo.bar",
              "updated" => "2023-11-15",
              relatedIdentifiers: [
                { "relatedIdentifierType" => "DOI" },
              ],
              creators: [],
            },
          }

          expect(NameIdentifier.push_item(item)).to(eq(nil))
        end
      end

      describe "when values" do
        describe "are valid" do
          it "send message to events for the first name identifier with scheme 'ORCID'" do
            item = {
              "attributes" => {
                "doi" => "https://doi.org/10.0001/foo.bar",
                "updated" => "2023-11-15",
                "creators" => [
                  "nameIdentifiers" => [
                    {
                      "nameIdentifierScheme" => "ORCID",
                      "nameIdentifier" => "https://orcid.org/0000-0000-0000-0000",
                    },
                    {
                      "nameIdentifierScheme" => "SNORCID",
                      "nameIdentifier" => "https://orcid.org/0000-0000-0000-0000",
                    },
                    {
                      "nameIdentifierScheme" => "ORCID",
                      "nameIdentifier" => "https://orcid.org/0000-0000-0000-0000",
                    },
                  ],
                ],
              },
            }

            expect(NameIdentifier.push_item(item)).to(eq(1))
            expect(NameIdentifier).to(have_received(:send_event_import_message).once)
          end

          it "if the DOI is in a client with client_type repository" do
            ## DOI in client with client_type repository
            doi = "10.82621/sf34-nn32"
            attributes = NameIdentifier.get_datacite_json(doi, include_client: true)
            response = { "id" => doi, "type" => "dois",
                          "attributes" => attributes }

            expect(NameIdentifier.push_item(response)).to (eq(1))
          end
        end

        describe "is invalid" do
          it "will not send a message the events queue" do
            allow(ENV).to(receive(:[]).with("DATACITE_ORCID_AUTO_UPDATE_SOURCE_TOKEN").and_return("DATACITE_ORCID_AUTO_UPDATE_SOURCE_TOKEN"))

            item = {
              "attributes" => {
                "doi" => "https://doi.org/10.0001/foo.bar",
                "updated" => "2023-11-15",
                "creators" => [
                  "nameIdentifiers" => [
                    {
                      "nameIdentifierScheme" => "ORCID",
                      "nameIdentifier" => "https://orcid.org/0000-0000-0000-0000",
                    },
                  ],
                ],
              },
            }

            expect(NameIdentifier.push_item(item)).to(eq(1))
            expect(NameIdentifier).not_to(receive(:send_event_import_message))
          end
        end
      end

      describe "STAFF_PROFILES_ADMIN_TOKEN" do
        describe "is valid" do
          it "makes request to volpino" do
            item = {
              "attributes" => {
                "doi" => "https://doi.org/10.0001/foo.bar",
                "updated" => "2023-11-15",
                "creators" => [
                  "nameIdentifiers" => [
                    {
                      "nameIdentifierScheme" => "ORCID",
                      "nameIdentifier" => "https://orcid.org/0000-0000-0000-0000",
                    },
                  ],
                ],
              },
            }

            NameIdentifier.push_item(item)

            expect(Maremma).
              to(have_received(:post).
                with(
                  "https://fake.volpino.com/claims",
                  data: volpino_json,
                  bearer: staff_profiles_admin_token,
                  content_type: "application/json",
                ))
          end
        end

        describe "is invalid" do
          it "does not make request to volpino" do
            allow(ENV).
              to(receive(:[]).
                with(staff_profiles_admin_token).
                and_return(nil))

            item = {
              "attributes" => {
                "doi" => "https://doi.org/10.0001/foo.bar",
                "updated" => "2023-11-15",
                "creators" => [
                  "nameIdentifiers" => [
                    {
                      "nameIdentifierScheme" => "ORCID",
                      "nameIdentifier" => "https://orcid.org/0000-0000-0000-0000",
                    },
                  ],
                ],
              },
            }

            expect(Maremma).
              not_to(have_received(:post).
                with(
                  "https://fake.volpino.com/claims",
                  data: volpino_json,
                  bearer: staff_profiles_admin_token,
                  content_type: "application/json",
                ))
          end
        end
      end
    end
  end
end
