require 'rails_helper'

describe "related_url:import_by_month", vcr: true do
  include ActiveJob::TestHelper
  include_context "rake"

  ENV['FROM_DATE'] = "2018-01-04"
  ENV['UNTIL_DATE'] = "2018-08-05"

  let(:output) { "Queued import for DOIs updated from 2018-01-01 until 2018-08-31.\n" }

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to eq(output)
  end

  it "should enqueue an RelatedUrlImportByMonthJob" do
    expect {
      capture_stdout { subject.invoke }
    }.to change(enqueued_jobs, :size).by(8)
    expect(enqueued_jobs.last[:job]).to be(RelatedUrlImportByMonthJob)
  end
end

describe "related_url:import", vcr: true do
  include ActiveJob::TestHelper
  include_context "rake"

  let(:output) { "Queued import for 122 DOIs updated from 2018-01-04 - 2018-08-05.\n" }

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to eq(output)
  end

  it "should enqueue an RelatedUrlImportJob" do
    expect {
      capture_stdout { subject.invoke }
    }.to change(enqueued_jobs, :size).by(122)
    expect(enqueued_jobs.last[:job]).to be(RelatedUrlImportJob)
  end
end