require 'rails_helper'

describe "crossref_funder:import_by_month", vcr: true do
  include ActiveJob::TestHelper
  include_context "rake"

  ENV['FROM_DATE'] = "2018-01-04"
  ENV['UNTIL_DATE'] = "2018-01-04"

  let(:output) { "Queued import for DOIs created from 2018-01-01" }

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to start_with(output)
  end

  it "should enqueue an CrossrefFunderImportByMonthJob" do
    expect {
      capture_stdout { subject.invoke }
    }.to change(enqueued_jobs, :size)
    expect(enqueued_jobs.last[:job]).to be(CrossrefFunderImportByMonthJob)
  end
end

describe "crossref_funder:import", vcr: true do
  include ActiveJob::TestHelper
  include_context "rake"

  let(:output) { "Queued import for 915613 DOIs created from 2018-01-04" }

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to start_with(output)
  end

  it "should enqueue an CrossrefFunderImportJob" do
    expect {
      capture_stdout { subject.invoke }
    }.to change(enqueued_jobs, :size).by(25)
    expect(enqueued_jobs.last[:job]).to be(CrossrefFunderImportJob)
  end
end
