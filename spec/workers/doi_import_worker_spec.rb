require 'rails_helper'

describe DoiImportWorker do
  context "doi", vcr: true do
    let(:data) { {"id":"10.5438/4k3m-nyvgx","type":"dois","attributes":{"doi":"10.5438/4k3m-nyvgx","state":"findable","created":"2018-10-07T05:42:35.000Z","updated":"2018-10-07T05:42:36.000Z"}} }
    let(:sqs_msg) { double message_id: 'fc754df7-9cc2-4c41-96ca-5996a44b771e', body: data, delete: nil }
    
    subject { DoiImportWorker.new }

    it 'works' do
      related_identifiers = subject.perform(sqs_msg, data)
      expect(related_identifiers.length).to eq(3)
      expect(related_identifiers.first).to eq("__content__"=>"10.5438/0000-00ss", "relatedIdentifierType"=>"DOI", "relationType"=>"IsPartOf")
    end
  end
end
