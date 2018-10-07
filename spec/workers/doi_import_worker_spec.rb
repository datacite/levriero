require 'rails_helper'

describe DoiImportWorker do
  context "doi", vcr: true do
    let(:data) { {"id":"10.17863/cam.6943","type":"dois","attributes":{"doi":"10.17863/cam.6943","state":"findable","created":"2018-10-07T05:42:35.000Z","updated":"2018-10-07T05:42:36.000Z"}} }
    let(:sqs_msg) { double message_id: 'fc754df7-9cc2-4c41-96ca-5996a44b771e', body: data, delete: nil }
    
    subject { DoiImportWorker.new }

    it 'works' do
      doi = subject.perform(sqs_msg, data)
      expect(doi["name"]).to eq("The response to receiving phenotypic and genetic coronary heart disease risk scores and lifestyle advice – a qualitative study")
    end
  end
end
