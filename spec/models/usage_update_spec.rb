require "rails_helper"

describe UsageUpdate, type: :model, vcr: true do
  describe "get_data" do
    context "when there are NO messages" do
      it "should return empty" do
        options = {}
        message = ""
        response = UsageUpdate.get_data(message, options)
        expect(response.body["errors"]).to eq("No Report given given")
      end
    end
  end

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
      end
    end

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

      it "should parsed it correctly from dataone with strange doi names" do
        body = File.read("#{fixture_path}dataone.json")
        result = OpenStruct.new(body: JSON.parse(body),
                                url: "https://api.stage.datacite.org/reports/f0e06846-7af1-4e43-a32b-8d299e99bd21")
        report = Report.new(result)
        args = { header: report.header, url: report.report_url }
        response = Report.translate_datasets(
          result.body.dig("data", "report", "report-datasets"), args
        )

        expect(response.last.fetch("obj-id")).to eq("https://doi.org/10.5063/aa/bowdish.122.10")
      end

      it "should parsed it correctly when it has five metrics  and two DOIs" do
        body = File.read("#{fixture_path}usage_update_3.json")
        result = OpenStruct.new(body: JSON.parse(body),
                                url: "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")
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
  end

  context "push_item" do
    it "should place a message on the events queue" do
      allow(ENV).to(receive(:[]).with("STAFF_ADMIN_TOKEN").and_return("token"))
      allow(UsageUpdate).to(receive(:send_event_import_message).and_return(nil))
      allow(Rails.logger).to(receive(:info))

      item = {
        "subj-id": "subj-id",
        "relation-type-id": "relation-type-id",
        "obj-id": "obj-id"
      }.to_json

       UsageUpdate.push_item(item)

      expect(UsageUpdate).to(have_received(:send_event_import_message).once)
      expect(Rails.logger).to(have_received(:info).with("[Event Data] subj-id relation-type-id obj-id sent to the events queue."))
    end
  end
end
