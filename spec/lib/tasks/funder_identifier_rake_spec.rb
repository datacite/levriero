require "rails_helper"

describe "funder_identifier:import_by_month", vcr: true do
  include ActiveJob::TestHelper
  include_context "rake"

  ENV["FROM_DATE"] = "2018-01-04"
  ENV["UNTIL_DATE"] = "2018-12-31"

  let(:output) do
    "Queued import for DOIs created from 2018-01-01 until 2018-12-31.\n"
  end

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to eq(output)
  end

  it "should enqueue an FunderIdentifierImportByMonthJob" do
    expect do
      capture_stdout { subject.invoke }
    end.to change(enqueued_jobs, :size).by(12)
    expect(enqueued_jobs.last[:job]).to be(FunderIdentifierImportByMonthJob)
  end
end

describe "funder_identifier:import", vcr: true do
  include ActiveJob::TestHelper
  include_context "rake"

  let(:output) do
    "Queued import for 30 DOIs created from 2018-01-04 - 2018-12-31.\n"
  end

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to eq(output)
  end

  it "should enqueue an FunderIdentifierImportJob" do
    expect do
      capture_stdout { subject.invoke }
    end.to change(enqueued_jobs, :size).by(25)
    expect(enqueued_jobs.last[:job]).to be(FunderIdentifierImportJob)
  end
end

describe "push_item" do
  it "returns nil when the doi is blank" do
    expect(FunderIdentifier.push_item({ attributes: { doi: nil } })).to(eq(nil))
  end

  describe "when STAFF_ADMIN_TOKEN" do
    before(:each) do
      allow(ENV).to(receive(:[]).with("LAGOTTINO_URL").and_return("https://fake.lagattino.com"))
      allow(ENV).to(receive(:[]).with("DATACITE_FUNDER_SOURCE_TOKEN").and_return("DATACITE_FUNDER_SOURCE_TOKEN"))
      allow(Base).to(receive(:cached_datacite_response).and_return({ "foo" => "bar" }))
      allow(Base).to(receive(:cached_funder_response).and_return({ "bar" => "foo" }))
      allow(Maremma).to(receive(:post).and_return(OpenStruct.new(status: 200)))
      allow(Time).to(receive_message_chain(:zone, :now, :iso8601).and_return("2023-11-15T12:17:47Z"))
      allow(FunderIdentifier).to(receive(:send_event_import_message).and_return(nil))
    end

    describe "is valid" do
      it "sends to events queue for those funder identifiers with funder identifier type 'Crossref Funder Id'" do
        item = {
          "attributes" => {
            "doi" => "https://doi.org/10.0001/foo.bar",
            "updated" => "2023-11-15",
            "fundingReferences" => [
              {
                "funderIdentifier" => "https://doi.org/10.0001/example.one",
                "funderIdentifierType" => "Crossref Funder ID",
              },
              {
                "funderIdentifier" => "https://doi.org/10.0001/example.two",
                "funderIdentifierType" => "Foo",
              },
              {
                "funderIdentifier" => "https://doi.org/10.0001/example.three",
                "funderIdentifierType" => "Crossref Funder ID",
              },
            ],
          },
        }

        expect(FunderIdentifier.push_item(item)).to(eq(2))
        expect(FunderIdentifier).to(have_received(:send_event_import_message).twice)
      end

      it "passes the expected values to lagottino" do
        item = {
          "attributes" => {
            "doi" => "https://doi.org/10.0001/foo.bar",
            "updated" => "2023-11-15",
            "fundingReferences" => [
              {
                "funderIdentifier" => "https://doi.org/10.0001/example.one",
                "funderIdentifierType" => "Crossref Funder ID",
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
              "relationTypeId" => "is-funded-by",
              "sourceId" => "datacite-funder",
              "sourceToken" => "DATACITE_FUNDER_SOURCE_TOKEN",
              "occurredAt" => "2023-11-15",
              "timestamp" => "2023-11-15T12:17:47Z",
              "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
              "subj" => { "foo" => "bar" },
              "obj" => { "bar" => "foo" },
            },
          },
        }

        expect(FunderIdentifier.push_item(item)).to(eq(1))
        expect(FunderIdentifier).to(have_received(:send_event_import_message).with(json_data.to_json).once)
      end
    end
  end
end
