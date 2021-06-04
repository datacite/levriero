require "rails_helper"

describe UsageUpdateExportJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  context "Client" do
    let(:item) { create(:event).to_json }
    subject(:job) { UsageUpdateExportJob.perform_later(item) }

    it "queues the job" do
      expect { job }.to have_enqueued_job(UsageUpdateExportJob).
        on_queue("test_levriero_usage")
    end

    # it 'performs' do
    #   expect(UsageUpdate).to receive(:item).with(item)
    #   UsageUpdateExportJob.perform_now(item)
    # end
  end
end
