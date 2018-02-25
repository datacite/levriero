require 'rails_helper'

describe ElasticImportWorker, elasticsearch: true do
  context "Client" do
    let(:client) { build(:client) }
    let(:data) { client.to_jsonapi }

    subject { ElasticImportWorker.new }

    it 'works' do
      client = subject.perform(data)
      expect(client).to be_valid
    end
  end

  context "Provider" do
    let(:provider) { build(:provider) }
    let(:data) { provider.to_jsonapi }

    subject { ElasticImportWorker.new }

    it 'works' do
      provider = subject.perform(data)
      expect(provider).to be_valid
    end
  end
end
