require 'rails_helper'

describe UsageUpdateImportJob, type: :job, vcr: true do
  include ActiveJob::TestHelper


  context "Client" do
    let(:item) { create(:event).to_json  }
    subject(:job) { UsageUpdateImportJob.perform_later(item) }

    it 'queues the job' do
      expect { job }.to have_enqueued_job(UsageUpdateImportJob)
        .on_queue("test_levriero")
    end

    # it 'performs' do
    #   expect(UsageUpdate).to receive(:item).with(item)
    #   UsageUpdateImportJob.perform_now(item)
    # end

  end
end



