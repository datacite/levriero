require "rails_helper"

describe "crossref:import_by_month", vcr: true do
  include ActiveJob::TestHelper
  include_context "rake"

  ENV["FROM_DATE"] = "2018-01-04"
  ENV["UNTIL_DATE"] = "2018-12-31"

  let(:output) do
    "Queued import for DOIs updated from 2018-01-01 until 2018-12-31.\n"
  end

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to eq(output)
  end

  it "should enqueue an ImportRelatedJob" do
    expect do
      capture_stdout { subject.invoke }
    end.to change(enqueued_jobs, :size).by(12)
    expect(enqueued_jobs.last[:job]).to be(CrossrefImportByMonthJob)
  end
end

# describe "crossref:import", vcr: true do
#   include ActiveJob::TestHelper
#   include_context "rake"

#   let(:output) do
#     "Queued import for 36129 DOIs updated from 2018-01-04 - 2018-12-31.\n"
#   end

#   it "prerequisites should include environment" do
#     expect(subject.prerequisites).to include("environment")
#   end

#   it "should run the rake task" do
#     expect(capture_stdout { subject.invoke }).to eq(output)
#   end

#   it "should enqueue an ImportRelatedJob" do
#     expect do
#       capture_stdout { subject.invoke }
#     end.to change(enqueued_jobs, :size).by(36129)
#     expect(enqueued_jobs.last[:job]).to be(CrossrefImportJob)
#   end
# end
