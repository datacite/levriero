require "rails_helper"

describe RelatedHandle, type: :model, vcr: true do
  context "instance methods" do
    subject { RelatedHandle.new }

    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2020-08-05" }

    it "get_query_url" do
      response = subject.get_query_url(from_date: from_date,
                                       until_date: until_date)
      expect(response).to eq("https://api.stage.datacite.org/dois?query=relatedIdentifiers.relatedIdentifierType%3AHandle+AND+updated%3A%5B2018-01-04T00%3A00%3A00Z+TO+2020-08-05T23%3A59%3A59Z%5D&resource-type-id=&page%5Bnumber%5D=1&page%5Bsize%5D=1000&exclude_registration_agencies=true&affiliation=true")
    end

    it "get_total" do
      response = subject.get_total(from_date: from_date, until_date: until_date)
      expect(response).to eq(321)
    end
  end

  context "class methods" do
    let(:from_date) { "2018-01-04" }
    let(:until_date) { "2020-08-05" }

    it "import_by_month" do
      response = RelatedHandle.import_by_month(from_date: from_date,
                                               until_date: until_date)
      expect(response).to eq("Queued import for DOIs updated from 2018-01-01 until 2020-08-31.")
    end

    it "import" do
      until_date = "2020-12-31"
      response = RelatedHandle.import(from_date: from_date,
                                      until_date: until_date)
      expect(response).to eq(321)
    end

    it "push_item" do
      allow(RelatedHandle).to(receive(:send_event_import_message).and_return(nil))
      allow(Rails.logger).to(receive(:info))

      doi = "10.20375/0000-001a-6248-5"
      attributes = RelatedHandle.get_datacite_json(doi)
      response = RelatedHandle.push_item({ "id" => doi, "type" => "dois", "attributes" => attributes })

      expect(RelatedHandle).to(have_received(:send_event_import_message).once)
      expect(Rails.logger).to(have_received(:info).with("[Event Data] https://doi.org/10.20375/0000-001a-6248-5 is_identical_to https://hdl.handle.net/21.t11991/0000-001a-6248-5 sent to the events queue."))
      expect(response).to eq(1)
    end
  end
end
