require "rails_helper"

describe DoiImportWorker do
  context "related_identifier", vcr: true do
    let(:doi) { "10.17863/cam.12119" }
    let(:data) do
      { "id" => doi, "type" => "dois",
        "attributes" => { "doi" => doi, "state" => "findable", "created" => "2018-10-07T05:42:35.000Z", "updated" => "2018-10-07T05:42:36.000Z" } }.to_json
    end
    let(:sqs_msg) do
      double message_id: "fc754df7-9cc2-4c41-96ca-5996a44b771e", body: data,
             delete: nil
    end

    subject { DoiImportWorker.new }

    it "find related_identifier" do
      # related_identifiers = subject.perform(sqs_msg, data)
      # expect(related_identifiers.length).to eq(1)
      # expect(related_identifiers.first).to eq("affiliation" => [],
      #   "familyName" => "Liu",
      #   "givenName" => "Yang",
      #   "name" => "Liu, Yang",
      #   "nameIdentifiers" => [{"nameIdentifier"=>"https://orcid.org/0000-0001-8865-4647", "nameIdentifierScheme"=>"ORCID", "schemeUri"=>"https://orcid.org"}],
      #   "nameType" => "Personal")
    end
  end

  context "name_identifier", vcr: true do
    let(:doi) { "10.17863/cam.9820" }
    let(:data) do
      { "id" => doi, "type" => "dois",
        "attributes" => { "doi" => doi, "state" => "findable", "created" => "2018-10-07T05:42:35.000Z", "updated" => "2018-10-07T05:42:36.000Z" } }.to_json
    end
    let(:sqs_msg) do
      double message_id: "fc754df7-9cc2-4c41-96ca-5996a44b771e", body: data,
             delete: nil
    end

    # subject { DoiImportWorker.new }

    # it 'find name_identifier' do
    #   name_identifiers = subject.perform(sqs_msg, data)
    #   expect(name_identifiers.length).to eq(2)
    #   expect(name_identifiers.first).to eq("affiliation" => [], "familyName" => "Coxon",
    #     "givenName" => "Paul",
    #     "name" => "Coxon, Paul",
    #     "nameIdentifiers" => [{"nameIdentifier"=>"https://orcid.org/0000-0001-9258-8259", "nameIdentifierScheme"=>"ORCID"}],
    #     "nameType" => "Personal")
    # end
  end

  context "funder_identifier", vcr: true do
    let(:doi) { "10.4224/crm.2010f.selm-1" }
    let(:data) do
      { "id" => doi, "type" => "dois",
        "attributes" => { "doi" => doi, "state" => "findable", "created" => "2018-10-07T05:42:35.000Z", "updated" => "2018-10-07T05:42:36.000Z" } }.to_json
    end
    let(:sqs_msg) do
      double message_id: "fc754df7-9cc2-4c41-96ca-5996a44b771e", body: data,
             delete: nil
    end

    # subject { DoiImportWorker.new }

    # it 'find funder_identifier' do
    #   identifiers = subject.perform(sqs_msg, data)
    #   expect(identifiers.length).to eq(17)
    #   expect(identifiers.last).to eq("affiliation" => [],
    #     "familyName" => "Yang",
    #     "givenName" => "Lu",
    #     "name" => "Yang, Lu",
    #     "nameIdentifiers" => [{"nameIdentifier"=>"https://orcid.org/0000-0002-4351-2503", "nameIdentifierScheme"=>"ORCID"}],
    #     "nameType" => "Personal")
    # end
  end
end
