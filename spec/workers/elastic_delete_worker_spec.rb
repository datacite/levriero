require 'rails_helper'

describe ElasticDeleteWorker, elasticsearch: true do
  context "Client" do
    let(:client) { create(:client) }
    let(:data) { client.to_jsonapi }

    subject { ElasticDeleteWorker.new }

    it 'works' do
      client = subject.perform(data)
      expect(client.destroyed?).to be true
    end
  end

  context "Provider" do
    let(:provider) { create(:provider) }
    let(:data) { provider.to_jsonapi }

    subject { ElasticDeleteWorker.new }

    it 'works' do
      provider = subject.perform(data)
      expect(provider.destroyed?).to be true
    end
  end
end
