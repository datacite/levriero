require 'rails_helper'

describe UsageUpdateParseJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  context "Client" do
    let(:item) { "https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad" }
    subject(:job) { UsageUpdateParseJob.perform_later(item) }

    it 'queues the job' do
      expect { job }.to have_enqueued_job(UsageUpdateParseJob)
        .on_queue("test_levriero")
    end

    # it 'execute further call' do
    #   perform_enqueued_jobs do
    #     UsageUpdateParseJob.new.perform(item)
    #   end
    # end
  end
end



