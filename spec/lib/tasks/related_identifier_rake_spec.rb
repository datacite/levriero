require 'rails_helper'

describe "related_identifier:import_by_month", vcr: true do
  include ActiveJob::TestHelper
  include_context "rake"

  ENV['FROM_DATE'] = "2018-01-04"
  ENV['UNTIL_DATE'] = "2018-12-31"

  let(:output) { "Queued import for DOIs created from 2018-01-01 until 2018-12-31.\n" }

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to eq(output)
  end

  it "should enqueue an RelatedIdentifierImportByMonthJob" do
    expect {
      capture_stdout { subject.invoke }
    }.to change(enqueued_jobs, :size).by(12)
    expect(enqueued_jobs.last[:job]).to be(RelatedIdentifierImportByMonthJob)
  end
end

describe "related_identifier:import", vcr: true do
  include ActiveJob::TestHelper
  include_context "rake"

  let(:output) { "Queued import for 2114 DOIs created from 2018-01-04 - 2018-12-31.\n" }

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to eq(output)
  end

  it "should enqueue an RelatedIdentifierImportJob" do
    expect {
      capture_stdout { subject.invoke }
    }.to change(enqueued_jobs, :size).by(3000)
    expect(enqueued_jobs.last[:job]).to be(RelatedIdentifierImportJob)
  end
end