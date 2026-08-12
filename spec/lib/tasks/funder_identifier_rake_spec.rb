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
  it "does not send events (out of scope)" do
    allow(FunderIdentifier).to(receive(:send_event_import_message).and_return(nil))

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

    expect(FunderIdentifier.push_item(item)).to(eq(0))
    expect(FunderIdentifier).not_to(have_received(:send_event_import_message))
  end
end
