require "rails_helper"

describe UsageUpdate, type: :model, vcr: true do
  describe "get_data" do
    # context "when there is ONE message" do
    #   it "should return the data for one message" do
    #     options ={}
    #     message= "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad"
    #     response = UsageUpdate.get_data(message,options)
    #     expect(response.body["data"]["report"]["report-header"]["report-name"]).to eq("Dataset Master Report")
    #   end
    # end

    context "when there are NO messages" do
      it "should return empty" do
        options = {}
        message = ""
        response = UsageUpdate.get_data(message, options)
        expect(response.body["errors"]).to eq("No Report given given")
      end
    end
  end

  # describe "queue" do
  #   context "get_total" do
  #     it "when is working with AWS" do
  #       expect(subject.get_total()).to respond_to(:+)
  #       expect(subject.get_total()).not_to respond_to(:each)
  #     end
  #   end

  #   context "get_message" do
  #     it "should return one message when there are multiple messages" do
  #       expect(subject.get_query_url).to respond_to(:each)
  #     end
  #   end
  # end

  describe "parse_data" do
    context "when the usage event was NOT found" do
      it "should return errors" do
        body = File.read("#{fixture_path}usage_update_nil.json")
        result = OpenStruct.new(body: JSON.parse(body))
        report = Report.new(result)
        args = { header: report.header, url: report.report_url }
        response = Report.translate_datasets(
          result.body.dig("data", "report", "report-datasets"), args
        )
        expect(response).to be_a(Array)
        expect(response).to be_empty

        # expect(response).to eq([{"status"=>"404", "title"=>"The resource you are looking for doesn't exist."}])
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
        body = File.read("#{fixture_path}usage_update_nil.json")
        result = OpenStruct.new(body: JSON.parse(body))
        report = Report.new(result)
        args = { header: report.header, url: report.report_url }
        response = Report.translate_datasets(
          result.body.dig("data", "report", "report-datasets"), args
        )

        expect(response).to be_a(Array)
        expect(response).to be_empty
        # expect(response).to eq([{"status"=>"404", "title"=>"The resource you are looking for doesn't exist."}])
      end
    end

    context "when the report was found" do
      it "should parsed it correctly" do
        body = File.read("#{fixture_path}usage_update.json")
        result = OpenStruct.new(body: JSON.parse(body),
                                url: "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")

        report = Report.new(result)
        args = { header: report.header, url: report.report_url }
        response = Report.translate_datasets(
          result.body.dig("data", "report", "report-datasets"), args
        )

        expect(response.length).to eq(2)
        expect(response.last.except("uuid")).to eq(
          "subj" => {
            "id" => "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "issued" => "2128-04-09"
          }, "total" => 3, "message-action" => "create", "subj-id" => "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "obj-id" => "https://doi.org/10.7291/d1q94r", "relation-type-id" => "unique-dataset-investigations-regular", "source-id" => "datacite-usage", "occurred-at" => "2013-11-02", "license" => "https://creativecommons.org/publicdomain/zero/1.0/", "source-token" => ENV["DATACITE_USAGE_SOURCE_TOKEN"]
        )
      end

      it "should parsed it correctly resolution" do
        body = File.read("#{fixture_path}resolution_update.json")
        result = OpenStruct.new(body: JSON.parse(body),
                                url: "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")

        report = Report.new(result)
        args = { header: report.header, url: report.report_url }
        response = Report.translate_datasets(
          result.body.dig("data", "report", "report-datasets"), args
        )

        expect(response.length).to eq(136)
        expect(response.last.except("uuid")).to eq(
          "subj" => {
            "id" => "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "issued" => "2018-10-28"
          }, "total" => 37, "message-action" => "create", "subj-id" => "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "obj-id" => "https://doi.org/10.6084/m9.figshare.6158567.v1", "relation-type-id" => "total-resolutions-machine", "source-id" => "datacite-resolution", "occurred-at" => "2019-05-01", "license" => "https://creativecommons.org/publicdomain/zero/1.0/", "source-token" => ENV["DATACITE_RESOLUTION_SOURCE_TOKEN"]
        )
      end

      # it "should parsed it correctly from call" do
      #   result = Maremma.get("https://api.stage.datacite.org/reports/1ca6c11f-dcc8-47ed-be45-53499687f0d1", host: "https://api.stage.datacite.org/")
      #   report = Report.new(result)
      #   args = { header: report.header, url: report.report_url }
      #   response = Report.translate_datasets(result.body.dig("data","report","report-datasets"), args)

      #   expect(response.length).to eq(1642)
      #   doi_instances =response.select {|instance| instance.dig("obj-id") == "https://doi.org/10.7272/q6qn64nk" }
      #   total_requests_regular = doi_instances.select {|instance| instance.dig("relation-type-id") == "total-dataset-requests-regular"}
      #   expect(total_requests_regular.first.dig("total")).to eq(1083)
      # end

      it "should parsed it correctly from dataone with strange doi names" do
        body = File.read("#{fixture_path}dataone.json")
        result = OpenStruct.new(body: JSON.parse(body),
                                url: "https://api.stage.datacite.org/reports/f0e06846-7af1-4e43-a32b-8d299e99bd21")
        # response = UsageUpdate.parse_data(result)
        report = Report.new(result)
        args = { header: report.header, url: report.report_url }
        response = Report.translate_datasets(
          result.body.dig("data", "report", "report-datasets"), args
        )

        expect(response.last.fetch("obj-id")).to eq("https://doi.org/10.5063/aa/bowdish.122.10")
        # expect(doi_instances.first.dig("total")).to eq(1083)
      end

      it "should parsed it correctly when it has five metrics  and two DOIs" do
        body = File.read("#{fixture_path}usage_update_3.json")
        result = OpenStruct.new(body: JSON.parse(body),
                                url: "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")
        # response = UsageUpdate.parse_data(result)
        report = Report.new(result)
        args = { header: report.header, url: report.report_url }
        response = Report.translate_datasets(
          result.body.dig("data", "report", "report-datasets"), args
        )
        expect(response.length).to eq(5)
        expect(response.last.except("uuid")).to eq("message-action" => "create",
                                                   "subj-id" => "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "subj" => { "id" => "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "issued" => "2128-04-09" }, "total" => 208, "obj-id" => "https://doi.org/10.6071/z7wc73", "relation-type-id" => "Unique-Dataset-Requests-Machine", "source-id" => "datacite-usage", "source-token" => ENV["DATACITE_USAGE_SOURCE_TOKEN"], "occurred-at" => "2013-11-02", "license" => "https://creativecommons.org/publicdomain/zero/1.0/")
      end

      it "should parsed it correctly when it has two metrics per DOI " do
        body = File.read("#{fixture_path}usage_update_2.json")
        result = OpenStruct.new(body: JSON.parse(body), url: "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")
        # response = UsageUpdate.parse_data(result)
        report = Report.new(result)
        args = { header: report.header, url: report.report_url }
        response = Report.translate_datasets(
          result.body.dig("data", "report", "report-datasets"), args
        )

        expect(response.length).to eq(4)
        expect(response.last.except("uuid")).to eq("message-action" => "create",
                                                   "subj-id" => "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "subj" => { "id" => "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad", "issued" => "2128-04-09" }, "total" => 208, "obj-id" => "https://doi.org/10.6071/z7wc73", "relation-type-id" => "Unique-Dataset-Requests-Machine", "source-id" => "datacite-usage", "source-token" => ENV["DATACITE_USAGE_SOURCE_TOKEN"], "occurred-at" => "2013-11-02", "license" => "https://creativecommons.org/publicdomain/zero/1.0/")
      end

      it "should send a warning if there are more than 4 metrics" do
        body = File.read("#{fixture_path}usage_update_1.json")
        result = OpenStruct.new(body: JSON.parse(body),
                                url: "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")
        # response = UsageUpdate.parse_data(result)
        report = Report.new(result)
        args = { header: report.header, url: report.report_url }
        response = Report.translate_datasets(
          result.body.dig("data", "report", "report-datasets"), args
        )

        expect(response.length).to eq(1)
        expect(response).to be_a(Array)
        expect(response.last.body).to eq({ "errors" => "There are too many instances in 10.7291/D1Q94R for report https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad. There can only be 4" })
      end
    end

    describe "parse_data compressed" do
      context "when the usage event is ok" do
        it "should return report parsed" do
          body = File.read("#{fixture_path}datacite_resolution_report_2018-09_encoded.json")
          result = OpenStruct.new(body: JSON.parse(body),
                                  url: "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")
          # parsed = UsageUpdate.parse_data(result)
          expect(Report.new(result).compressed_report?).to be(true)
        end
      end
    end

    describe "get_query_url" do
      context "when is ok" do
        it "should return url" do
          expect(UsageUpdate.get_query_url(number: 4, year: 2020)).to eq("https://api.stage.datacite.org/reports?page%5Bnumber%5D=4&page%5Bsize%5D=25&year=2020")
        end
      end
    end

    # describe "parse_data compressed 2" do
    #   context "when the usage event is ok" do
    #     it "should return report parsed" do
    #       body = File.read(fixture_path + 'datacite_resolution_report_2018-09_encoded.json')
    #       result = OpenStruct.new(body:  JSON.parse(body), url:"https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad" )
    #       parsed = Report.new(result).parse_data
    #       # puts parsed
    # checksum is wrong
    #       expect(parsed).to be_a(Array)
    #       expect(parsed.size).to eq(95056)
    #     end
    #   end
    # end
  end

  describe "wrap event" do
    let(:options) do
      { report_meta: {
        report_id: "1a6e79ea-5291-4f5f-a25e-2cb071715bfc",
        created_by: "datacite",
        reporting_period: "",
      } }
    end
    let(:item) do
      { "obj-id" => "https://doi.org/10.14278/rodaretest.11", "total" => 45 }
    end

    it "should format correctly" do
      # expect((UsageUpdate.wrap_event(item,options)).dig("data","attributes","obj")).to eq({"id"=>"https://doi.org/10.14278/rodaretest.11", "type"=>"dataset", "name"=>"Large Image", "author"=>[{"given_name"=>"Tester", "family_name"=>"Test"}], "publisher"=>"Rodare", "date_published"=>"2018-04-10", "date_modified"=>"2018-10-28T02:01:02.000Z", "registrant_id"=>"datacite.tib.hzdr"})
      # expect((UsageUpdate.wrap_event(item,options)).dig("data","attributes","total")).to eq(45)
    end
  end

  context "push_data" do
    let!(:events) { create_list(:event, 10) }

    it "should work with a single item" do
      body = File.read("#{fixture_path}usage_events.json")
      result = JSON.parse(body).first.to_json
      options = {}
      # expect(UsageUpdate.push_item(result, options)).to eq(true)
    end
  end
end
