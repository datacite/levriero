require "rails_helper"

describe RelatedIdentifier, type: :model, vcr: true do
  let(:from_date) { "2018-01-04" }
  let(:until_date) { "2018-08-05" }
  let(:doi) { "10.5061/dryad.j86rt6b" }

  describe ".import_by_month" do
    it "queues jobs for DOIs created within the specified month range" do
      allow(RelatedIdentifierImportByMonthJob).to receive(:perform_later)
      response = RelatedIdentifier.import_by_month(from_date: from_date, until_date: until_date)
      expect(RelatedIdentifierImportByMonthJob).to have_received(:perform_later).at_least(:once)
      expect(response).to eq("Queued import for DOIs created from 2018-01-01 until 2018-08-31.")
    end
  end

  describe ".import" do
    it "queues jobs for DOIs updated within the specified date range" do
      allow_any_instance_of(RelatedIdentifier).to receive(:queue_jobs).and_return(97)
      response = RelatedIdentifier.import(from_date: from_date, until_date: until_date)
      expect(response).to eq(97)
    end
  end

  describe "#source_id" do
    it "returns the source_id" do
      related_identifier = RelatedIdentifier.new
      expect(related_identifier.source_id).to eq("datacite_related")
    end
  end

  describe "#query" do
    it "returns the query string for related identifiers" do
      related_identifier = RelatedIdentifier.new
      expect(related_identifier.query).to eq("relatedIdentifiers.relatedIdentifierType:DOI")
    end
  end

  describe "#push_data" do
    it "pushes data and returns the number of items processed" do
      result = double(body: { "data" => [{ "id" => "example_id",
                                           "attributes" => { "doi" => "example_doi", "updated" => "2023-01-01" } }] })
      allow_any_instance_of(RelatedIdentifier).to receive(:cached_doi_ra).and_return("DataCite")
      allow(Maremma).to receive(:post).and_return(double(status: 201))
      allow(Time).to receive(:zone).and_return(double(now: Time.new(2023, 1, 1)))

      # Create a spy for perform_later method
      job_spy = class_double("RelatedIdentifierImportJob", perform_later: true)
      allow(RelatedIdentifierImportJob).to receive(:perform_later).and_return(job_spy)

      response = RelatedIdentifier.new.push_data(result)

      expect(RelatedIdentifierImportJob).to have_received(:perform_later).once
      expect(response).to eq(1)
    end

    it "returns errors if present in the API response" do
      result = double(body: { "errors" => "Example error" })
      response = RelatedIdentifier.new.push_data(result)
      expect(response).to eq("Example error")
    end
  end

  describe "#push_item" do
    let(:valid_doi) { "https://doi.org/10.0001/foo.bar" }
    let(:valid_related_identifier) { "https://doi.org/10.0001/example.one" }
    let(:item) do
      {
        "attributes" => {
          "doi" => "https://doi.org/10.1234/example",
          "updated" => "2023-11-15",
          "relatedIdentifiers" => [
            {
              "relatedIdentifierType" => "DOI",
              "relatedIdentifier" => "https://doi.org/10.5678/related",
              "relationType" => "example-type",
            },
          ],
        },
      }
    end

    context "when the DOI and related identifiers are valid" do
      before do
        allow(ENV).to receive(:[]).with("LAGOTTINO_URL").and_return("https://fake.lagattino.com")
        allow(ENV).to receive(:[]).with("DATACITE_RELATED_SOURCE_TOKEN").and_return("DATACITE_RELATED_SOURCE_TOKEN")
        allow(ENV).to receive(:[]).with("USER_AGENT").and_return("default_user_agent")
        allow(ENV).to receive(:[]).with("EVENTDATA_TOKEN").and_return("EVENTDATA_TOKEN")
        allow(ENV).to receive(:[]).with("EVENTDATA_URL").and_return("https://fake.eventdataurl.com")
        allow(Base).to receive(:cached_datacite_response).and_return({ "foo" => "bar" })
        allow(Maremma).to receive(:post).and_return(OpenStruct.new(status: 201))
        allow(RelatedIdentifier).to receive(:send_event_import_message).and_return(nil)
        allow(Time.zone).to receive(:now).and_return(Time.zone.parse("2023-11-15T12:17:47Z"))
      end

      it "queues jobs and pushes to the events queue" do
        related_identifier = RelatedIdentifier.new
        allow(related_identifier).to receive(:normalize_doi).with(valid_doi).and_return("normalized_doi")
        allow(related_identifier).to receive(:normalize_doi).with(valid_related_identifier).and_return("normalized_related_identifier")
        allow(related_identifier).to receive(:validate_prefix).with(valid_related_identifier).and_return("datacite")
        allow(RelatedIdentifier).to receive(:cached_doi_ra).and_return("DataCite")
        allow(RelatedIdentifier).to receive(:cached_datacite_response).and_return({})
        allow(related_identifier).to receive(:set_event_for_bus).and_return({})
        allow(Rails.logger).to receive(:info)

        expect(RelatedIdentifier.push_item(item)).to eq(1)
        expect(RelatedIdentifier).to have_received(:send_event_import_message).once

        expect(Rails.logger).to have_received(:info).with("[Event Data] https://doi.org/10.1234/example example_type https://doi.org/10.5678/related sent to the events queue.")
      end

      it "does push the event to the event data bus when source_id is datacite_crossref" do
        related_identifier = RelatedIdentifier.new
        allow(ENV).to receive(:[]).with("DATACITE_CROSSREF_SOURCE_TOKEN").and_return("fake-token")
        allow(related_identifier).to receive(:normalize_doi).with(valid_doi).and_return("normalized_doi")
        allow(related_identifier).to receive(:normalize_doi).with(valid_related_identifier).and_return("normalized_related_identifier")
        allow(related_identifier).to receive(:validate_prefix).with(valid_related_identifier).and_return("datacite")
        allow(RelatedIdentifier).to receive(:cached_doi_ra).with("https://doi.org/10.5678/related").and_return("Crossref")
        allow(RelatedIdentifier).to receive(:cached_doi_ra).with("https://doi.org/10.1234/example").and_return("DataCite")
        allow(RelatedIdentifier).to receive(:cached_crossref_response).and_return({})
        allow(RelatedIdentifier).to receive(:cached_datacite_response).and_return({})
        allow(related_identifier).to receive(:set_event_for_bus).and_return({})
        allow(Rails.logger).to receive(:info)

        expect(RelatedIdentifier.push_item(item)).to eq(1)
        expect(RelatedIdentifier).to have_received(:send_event_import_message).once
        expect(Maremma).to have_received(:post).with("https://fake.eventdataurl.com/events", anything).once
        expect(Rails.logger).to have_received(:info).with("[Event Data] https://doi.org/10.1234/example example_type https://doi.org/10.5678/related sent to the events queue.")
        expect(Rails.logger).to have_received(:info).with("[Event Data Bus] https://doi.org/10.1234/example example_type https://doi.org/10.5678/related pushed to Event Data service.")
      end
    end

    context "when the DOI is blank" do
      it "returns nil" do
        allow(RelatedIdentifier).to receive(:send_event_import_message).and_return(nil)
        item = {
          "attributes" => {
            "doi" => nil,
            "relatedIdentifiers" => [
              {
                "relatedIdentifierType" => "DOI",
                "relatedIdentifier" => valid_related_identifier,
                "relationType" => "example-one",
              },
            ],
          },
        }

        expect(RelatedIdentifier.push_item(item)).to eq(nil)
        expect(RelatedIdentifier).not_to have_received(:send_event_import_message)
      end
    end
  end
end
