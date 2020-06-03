require 'rails_helper'

describe UsageUpdateImportWorker do
  context "usage_report", vcr: true do
    let(:data) { {"report_id"=>"https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad"}.to_json }
    let(:sqs_msg) { double message_id: 'fc754df7-9cc2-4c41-96ca-5996a44b771e', body: data, delete: nil }
    
    subject { UsageUpdateImportWorker.new }

    it 'find usage reports' do
      parse_job = subject.perform(sqs_msg, data)
      expect(parse_job.arguments.first).to eq("https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")
    end
  end

  # context "funder_identifier", vcr: true do
  #   let(:doi) { "10.0133/32096" }
  #   let(:data) { { "id" => doi, "type" => "dois", "attributes" => {"doi" => doi, "state" => "findable", "created" => "2018-10-07T05:42:35.000Z","updated" => "2018-10-07T05:42:36.000Z"}}.to_json }
  #   let(:sqs_msg) { double message_id: 'fc754df7-9cc2-4c41-96ca-5996a44b771e', body: data, delete: nil }
  
  #   it 'find funder_identifier' do
  #     funder_identifiers = subject.perform(sqs_msg, data)
  #     expect(funder_identifiers.length).to eq(1)
  #     expect(funder_identifiers.first).to eq("awardNumber" => {"__content__"=>"BE 1042/7-1", "awardURI"=>"http://gepris.dfg.de/gepris/projekt/237143194"},
  #       "awardTitle" => "RADAR Research Data Repositorium",
  #       "funderIdentifier" => {"__content__"=>"http://dx.doi.org/10.13039/501100001659", "funderIdentifierType"=>"Crossref Funder ID"},
  #       "funderName" => "DFG")
  #   end
  # end
end
