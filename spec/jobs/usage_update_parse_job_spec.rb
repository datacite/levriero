require "rails_helper"

describe UsageUpdateParseJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  context "Client" do
    let(:item) do
      "https://api.stage.datacite.org/reports/d4cccd37-9044-4c59-85d4-f2063ce361cd"
    end
    let(:body) { File.read("#{fixture_path}usage_update_3.json") }
    let(:result) do
      OpenStruct.new(body: JSON.parse(body),
                     url: "https://api.stage.datacite.org/reports/d4cccd37-9044-4c59-85d4-f2063ce361cd")
    end
    let(:report) { Report.new(result) }
    let(:args) { { header: report.header, url: report.report_url } }
    subject(:job) { UsageUpdateParseJob.perform_later(report.datasets, args) }

    it "queues the job" do
      expect { job }.to have_enqueued_job(UsageUpdateParseJob).
        on_queue("test_levriero_usage")
    end

    it "execute further call" do
      response = perform_enqueued_jobs do
        UsageUpdateParseJob.new.perform(report.datasets, args)
      end
      expect(response).not_to be_a(Hash)
    end
  end

  context "not existing report" do
    let(:item) do
      "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1-95cf-ba2f475cbfad"
    end
    let(:body)   { File.read("#{fixture_path}usage_update_3.json") }
    let(:result) do
      OpenStruct.new(body: JSON.parse(body),
                     url: "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1-95cf-ba2f475cbfad")
    end
    let(:report) { Report.new(result) }
    let(:args) { { header: report.header, url: report.report_url } }
    subject(:job) { UsageUpdateParseJob.perform_later(report.datasets, args) }

    it "queues the job" do
      expect { job }.to have_enqueued_job(UsageUpdateParseJob).
        on_queue("test_levriero_usage")
    end

    it "execute further call" do
      response = perform_enqueued_jobs do
        # UsageUpdateParseJob.new.perform(item, report.datasets)
      end
      # expect(response).to be_a(Hash)
    end
  end
end
