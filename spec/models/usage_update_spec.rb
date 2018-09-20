require 'rails_helper'

describe UsageUpdate, type: :model, vcr: true do


  describe "get_data" do
    # context "when there are messages" do
    #   it "should return the data for one message" do
    #     sqs.stub_responses(:receive_message, messages: message)
    #     sqs.stub_responses(:receive_message, messages: message)
    #     sqs.stub_responses(:receive_message, messages: message)
    #     sqs.stub_responses(:receive_message, messages: message)
    #     response = sqs.receive_message({queue_url: queue_url})
    #     response = subject.get_data(response)
    #     expect(response.body["data"]["report"]["report-header"]["report-name"]).to eq("Dataset Master Report")
    #   end
    # end

    # context "when there is ONE message" do
    #   it "should return the data for one message" do
    #     sqs.stub_responses(:receive_message, messages: message)
    #     response = sqs.receive_message({queue_url: queue_url})
    #     response = subject.get_data(response)
    #     expect(response.body["data"]["report"]["report-header"]["report-name"]).to eq("Dataset Master Report")
    #   end
    # end

    # context "when there are NOT messages" do
    #   it "should return empty" do
    #     sqs.stub_responses(:receive_message, messages: [])
    #     response = sqs.receive_message({queue_url: queue_url})
    #     response = subject.get_data(response)
    #     expect(response.body["errors"]).to eq("Queue is empty")
    #   end
    # end
  end

  describe "queue" do 
    context "get_total" do
      it "when is working with AWS" do
        expect(subject.get_total()).to respond_to(:+)
        expect(subject.get_total()).not_to respond_to(:each)
      end
    end

    context "get_message" do
      it "should return one message when there are multiple messages" do
        expect(subject.get_query_url).to respond_to(:each)
      end

      it "should return no meessage when the queue is empty" do
        expect(subject.get_query_url).not_to respond_to(:+)
      end
    end
  end

  describe "parse_data" do
    context "when the usage event was NOT found" do
      it "should return errors" do
        body = File.read(fixture_path + 'usage_update_nil.json')
        result = OpenStruct.new(body:  JSON.parse(body) )
        expect(UsageUpdate.parse_data(result)).to be_a(Array)
        expect(UsageUpdate.parse_data(result)).to eq([{"status"=>"404", "title"=>"The resource you are looking for doesn't exist."}])
      end
    end

    # context "when the queue is empty" do
    #   it "should return errors" do
    #     result = OpenStruct.new(body: { "errors" => "Queue is empty" })
    #     expect(subject.parse_data(result)).to be_a(Array)
    #     expect(subject.parse_data(result)).to eq([{"status"=>"404", "title"=>"The resource you are looking for doesn't exist."}])
    #   end
    # end

    context "when the usage report was NOT found" do
      it "should return errors" do
        body = File.read(fixture_path + 'usage_update_nil.json')
        result = OpenStruct.new(body:  JSON.parse(body) )
        expect(UsageUpdate.parse_data(result)).to be_a(Array)
        expect(UsageUpdate.parse_data(result)).to eq([{"status"=>"404", "title"=>"The resource you are looking for doesn't exist."}])
      end
    end

    context "when the report was found" do
      it "should parsed it correctly" do
        body = File.read(fixture_path + 'usage_update.json')
        result = OpenStruct.new(body: JSON.parse(body), url:"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad"  )
        response = UsageUpdate.parse_data(result)
        expect(response.length).to eq(2)
        expect(response.last.except("uuid")).to eq("subj"=>{"id"=>"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "issued"=>"2128-04-09"},"total"=>3,"message-action" => "create", "subj-id"=>"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "obj-id"=>"https://doi.org/10.7291/d1q94r", "relation-type-id"=>"unique-dataset-investigations-regular", "source-id"=>"datacite-usage", "occurred-at"=>"2128-04-09", "license" => "https://creativecommons.org/publicdomain/zero/1.0/", "source-token" => ENV['SASHIMI_SOURCE_TOKEN'])
      end

      it "should parsed it correctly when it has five metrics  and two DOIs" do
        body = File.read(fixture_path + 'usage_update_3.json')
        result = OpenStruct.new(body: JSON.parse(body), url:"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad"  )
        response = UsageUpdate.parse_data(result)
        expect(response.length).to eq(5)
        expect(response.last.except("uuid")).to eq("message-action"=>"create", "subj-id"=>"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "subj"=>{"id"=>"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "issued"=>"2128-04-09"}, "total"=>208, "obj-id"=>"https://doi.org/10.6071/z7wc73", "relation-type-id"=>"Unique-Dataset-Requests-Machine", "source-id"=>"datacite-usage", "source-token"=>ENV['SASHIMI_SOURCE_TOKEN'], "occurred-at"=>"2128-04-09", "license"=>"https://creativecommons.org/publicdomain/zero/1.0/")
      end

      it "should parsed it correctly when it has two metrics per DOI " do
        body = File.read(fixture_path + 'usage_update_2.json')
        result = OpenStruct.new(body: JSON.parse(body), url:"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")
        response = UsageUpdate.parse_data(result)
        expect(response.length).to eq(4)
        expect(response.last.except("uuid")).to eq("message-action"=>"create", "subj-id"=>"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "subj"=>{"id"=>"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "issued"=>"2128-04-09"}, "total"=>208, "obj-id"=>"https://doi.org/10.6071/z7wc73", "relation-type-id"=>"Unique-Dataset-Requests-Machine", "source-id"=>"datacite-usage", "source-token"=>ENV['SASHIMI_SOURCE_TOKEN'], "occurred-at"=>"2128-04-09", "license"=>"https://creativecommons.org/publicdomain/zero/1.0/")
      end

      it "should send a warning if there are more than 4 metrics" do
        body = File.read(fixture_path + 'usage_update_1.json')
        result = OpenStruct.new(body: JSON.parse(body), url:"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad"  )
        response = UsageUpdate.parse_data(result)
        expect(response.length).to eq(1)
        expect(UsageUpdate.parse_data(result)).to be_a(Array)
        expect(response.last.body).to eq({"errors"=>"There are too many instances in 10.7291/D1Q94R for report https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad. There can only be 4"})
      end
    end
  end

  context "push_data" do
    let!(:events) {create_list(:event,10)}
    it "should report if there are no works returned by the Queue" do
      result = []
      expect { UsageUpdate.push_data(result) }.to output("No works found in the Queue.\n").to_stdout
    end

    it "should fail if format of the event is wrong" do
      body = File.read(fixture_path + 'usage_events.json')
      expect = File.read(fixture_path + 'event_data_resp_2')
      # result = JSON.parse(body)
      options = { }
      expect(UsageUpdate.push_data(body, options)).to eq(4)
    end

    it "should fail if format of the event is empty" do
      body = File.read(fixture_path + 'events_empty.json')
      # result = JSON.parse(body)
      options = { }
      expect((UsageUpdate.push_data(body, options))).to eq(2)
    end

    # it "should work with DataCite Event Data 2" do
    #   dd = events.map {|event| event.to_h.stringify_keys}
    #   all_events = dd.map {|item| item.map{ |k, v| [k.dasherize, v] }.to_h}
    #   options = { }
    #   expect(subject.push_data(all_events, options)).to eq(0)
    # end

    it "should work with a single item" do
      body = File.read(fixture_path + 'usage_events.json')
      result = JSON.parse(body).first.to_json
      options = { }
      # expect(UsageUpdate.push_item(result, options)).to eq(true)
    end
  end

end
