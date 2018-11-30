require 'rails_helper'

describe Report, type: :model, vcr: true do
  let(:body)     {File.read(fixture_path + 'resolution_compress_small.json')}
  let(:response) {OpenStruct.new(body:  JSON.parse(body) )}
  let(:report)   {Report.new(response)}


  describe "parse_multi_subset_report" do
    context "when report is ok" do
      let(:body)  {File.read(fixture_path + 'multi_subset_report.json')}
      let(:uncompressed)  {File.read(fixture_path + 'datacite_resolution_report_2018-09.json')}
      let(:result) {OpenStruct.new(body: JSON.parse(body), url:"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")}
      let(:report) {Report.new(result)}

   
    it "should parsed it give you two arrays that are in every gzip" do
      live_results = Maremma.get("https://api.test.datacite.org/reports/9e5461d8-0713-4abd-8e87-e4533a76ab3d", host: "https://api.test.datacite.org/")
      report = Report.new(live_results)

      rr = Report.parse_multi_subset_report report
      expect(rr.size).to eq(2)
      expect(rr).to be_a(Array)
    end
  end
end

describe "parse_normal_report" do
  context "when report is ok" do
    let(:body)  {File.read(fixture_path + 'multi_subset_report.json')}
    let(:uncompressed)  {File.read(fixture_path + 'datacite_resolution_report_2018-09.json')}
    let(:result) {OpenStruct.new(body: JSON.parse(body), url:"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad")}
    let(:report) {Report.new(result)}

 
  it "should parsed it give you two arrays that are in every gzip" do
    live_results = Maremma.get("https://api.datacite.org/reports/21fd2e8e-5481-4bbd-b2ef-742d8b270a66", host: "https://api.datacite.org/")
    report = Report.new(live_results)

    rr = Report.parse_normal_report report
    expect(rr.size).to eq(409)
    expect(rr).to be_a(Array)
    expect(rr.first.dig("data-type")).to eq("dataset")
    expect(rr.first.fetch("performance",nil)).not_to be_nil
  end
end
end

  describe "translate_datasets" do
    context "when the report is good" do
      it "should return a good json" do
        live_results = Maremma.get("https://api.test.datacite.org/reports/9e5461d8-0713-4abd-8e87-e4533a76ab3d", host: "https://api.test.datacite.org/")
        report = Report.new(live_results)
  
        arrays = Report.parse_multi_subset_report report
        events = report.translate_datasets arrays.first


        expect(events.size).to eq(1243)
        expect(events.size).to eq(1243)
        expect(events.first.dig("source-id")).to eq("datacite-usage")
      end
    end
  end

  describe "get_type" do
    context "when there the report is good" do
      it "should return the data for one message" do
        live_results = Maremma.get("https://api.test.datacite.org/reports/9e5461d8-0713-4abd-8e87-e4533a76ab3d", host: "https://api.test.datacite.org/")
        report = Report.new(live_results)
        expect(report.get_type).to eq("compressed")
      end
    end
  end

  describe "compressed_report" do
    context "when there the report is good" do
      it "should return the data for one message" do
        live_results = Maremma.get("https://api.test.datacite.org/reports/9e5461d8-0713-4abd-8e87-e4533a76ab3d", host: "https://api.test.datacite.org/")
        report = Report.new(live_results)
        expect(report.get_type).to eq("compressed")
      end
    end
  end

  # describe "parse_subset" do
  #   context "when there the report is good" do
  #     it "should return a json array" do
  #       subset = Report.parse_subset uncompressed
  #       expect(subset).to be_a("Array")
  #       expect(subset.dig(1,"dataset-id")).to eq("dsdsdsdsds")
  #     end
  #   end
  # end

  # describe "correct_checksum" do
  #   context "when there the report is good" do
  #     it "should return true" do
  #       checksum = report.data.dig("report-datasets",1,"checksum")
  #       encoded_report = report.data.dig("report-datasets",1,"gzip")
  #       result = Report.correct_checksum? encoded_report, checksum
  #       expect(result).to eq(true)
  #     end
  #   end
  # end

end
