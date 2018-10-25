require 'rails_helper'

describe DoiImportWorker do
  context "related_identifier", vcr: true do
    let(:doi) { "10.5438/4k3m-nyvgx" }
    let(:data) { { "id" => doi, "type" => "dois", "attributes" => {"doi" => doi, "state" => "findable", "created" => "2018-10-07T05:42:35.000Z","updated" => "2018-10-07T05:42:36.000Z"}}.to_json }
    let(:sqs_msg) { double message_id: 'fc754df7-9cc2-4c41-96ca-5996a44b771e', body: data, delete: nil }
    
    subject { DoiImportWorker.new }

    it 'find related_identifier' do
      related_identifiers = subject.perform(sqs_msg, data)
      expect(related_identifiers.length).to eq(4)
      expect(related_identifiers.first).to eq("__content__"=>"10.5438/0000-00ss", "relatedIdentifierType"=>"DOI", "relationType"=>"IsPartOf")
    end
  end

  context "name_identifier", vcr: true do
    let(:doi) { "10.5438/0x88-gvge" }
    let(:data) { { "id" => doi, "type" => "dois", "attributes" => {"doi" => doi, "state" => "findable", "created" => "2018-10-07T05:42:35.000Z","updated" => "2018-10-07T05:42:36.000Z"}}.to_json }
    let(:sqs_msg) { double message_id: 'fc754df7-9cc2-4c41-96ca-5996a44b771e', body: data, delete: nil }
    
    subject { DoiImportWorker.new }

    it 'find name_identifier' do
      name_identifiers = subject.perform(sqs_msg, data)
      expect(name_identifiers.length).to eq(4)
      expect(name_identifiers.first).to eq("__content__"=>"10.5438/0000-00ss", "relatedIdentifierType"=>"DOI", "relationType"=>"IsPartOf")
    end
  end

  context "funder_identifier", vcr: true do
    let(:doi) { "10.0133/32096" }
    let(:data) { { "id" => doi, "type" => "dois", "attributes" => {"doi" => doi, "state" => "findable", "created" => "2018-10-07T05:42:35.000Z","updated" => "2018-10-07T05:42:36.000Z"}}.to_json }
    let(:sqs_msg) { double message_id: 'fc754df7-9cc2-4c41-96ca-5996a44b771e', body: data, delete: nil }
  
    it 'find funder_identifier' do
      funder_identifiers = subject.perform(sqs_msg, data)
      expect(funder_identifiers.length).to eq(2)
      expect(funder_identifiers.last).to eq("awardNumber" => {"__content__"=>"BE 1042/7-1", "awardURI"=>"http://gepris.dfg.de/gepris/projekt/237143194"},
        "awardTitle" => "RADAR Research Data Repositorium",
        "funderIdentifier" => {"__content__"=>"http://dx.doi.org/10.13039/501100001659", "funderIdentifierType"=>"Crossref Funder ID"},
        "funderName" => "DFG")
    end
  end
end
