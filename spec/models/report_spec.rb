require "rails_helper"

describe Report, type: :model, vcr: true do
  let(:body)     { File.read("#{fixture_path}resolution_compress_small.json") }
  let(:response) { OpenStruct.new(body: JSON.parse(body)) }
  let(:report)   { Report.new(response) }
  let(:url) do
    "https://api.stage.datacite.org/reports/9e5461d8-0713-4abd-8e87-e4533a76ab3d"
  end

  describe "parse_multi_subset_report" do
    context "when report is ok" do
      it "should parse and return all datasets from all subsets" do
        allow(UsageUpdateParseJob).to receive(:perform_later)

        response = UsageUpdate.get_data("https://api.datacite.org/reports/d0b2b372-1d0a-4aa6-8aad-a04673050cb2")
        report = Report.new(response)
        rr = Report.parse_multi_subset_report report
        
        expect(rr).to be_a(Array)
        expect(rr.size).to eq(57929)
        expect(rr.first.dig("performance")).to be_present
      end
    end
  end

  describe "parse_normal_report" do
    context "when report is ok" do
      let(:body)  { File.read("#{fixture_path}multi_subset_report.json") }
      let(:result) do
        OpenStruct.new(body: JSON.parse(body),
                       url: "https://api.stage.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")
      end
      let(:report) { Report.new(result) }

      it "should parsed it give you two arrays that are in every gzip" do
        live_results = Maremma.get(
          "https://api.datacite.org/reports/21fd2e8e-5481-4bbd-b2ef-742d8b270a66", host: "https://api.datacite.org/"
        )
        report = Report.new(live_results)
        rr = Report.parse_normal_report report
        expect(rr.size).to eq(0)
        # expect(rr).to be_a(Array)
        # expect(rr.first.dig("data-type")).to eq("dataset")
        # expect(rr.first.fetch("performance",nil)).not_to be_nil
      end
    end
  end

  # describe "get_type" do
  #   context "when there the report is good" do
  #     it "should return the data for one message" do
  #       live_results = Maremma.get(url, host: "https://api.stage.datacite.org/")
  #       report = Report.new(live_results)
  #       expect(report.get_type).to eq("compressed")
  #     end
  #   end
  # end

  # describe "compressed_report" do
  #   context "when there the report is good" do
  #     it "should return the data for one message" do
  #       live_results = Maremma.get(url, host: "https://api.stage.datacite.org/")
  #       report = Report.new(live_results)
  #       expect(report.get_type).to eq("compressed")
  #     end
  #   end
  # end
end
