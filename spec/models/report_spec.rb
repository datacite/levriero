require 'rails_helper'

describe Report, type: :model, vcr: true do
  let(:body)     {File.read(fixture_path + 'resolution_compress_small.json')}
  let(:response) {OpenStruct.new(body:  JSON.parse(body) )}
  let(:report)   {Report.new(response)}



  describe "decompress_report" do
    context "different calls" do
      # it "should parsed it correctly from call" do
      #   result = Maremma.get("https://api.datacite.org/reports/3c32bfab-2db2-4eb4-9f27-d800e86cd57b", host: "https://api.test.datacite.org/")
      #   # result = OpenStruct.new(body: JSON.parse(body), url:"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad"  )
      #   # response = UsageUpdate.parse_data(result)
      #   response = Report.new(result).parse_data
      #   # puts result
      #   # puts response
      #   expect(response.length).to eq(1642)
      #   doi_instances =response.select {|instance| instance.dig("obj-id") == "https://doi.org/10.7272/q6qn64nk" }
      #   total_requests_regular = doi_instances.select {|instance| instance.dig("relation-type-id") == "total-dataset-requests-regular"}
      #   expect(total_requests_regular.first.dig("total")).to eq(1083)
      # end

      # it "should parsed it correctly from call 2" do
      #   result = Maremma.get("https://api.test.datacite.org/reports/e6ad55b7-53cd-4525-9933-88bd3638d415", host: "https://api.test.datacite.org/")
      #   # result = OpenStruct.new(body: JSON.parse(body), url:"https://api.test.datacite.org/reports/5cac6ca0-9391-4e1d-95cf-ba2f475cbfad"  )
      #   # response = UsageUpdate.parse_data(result)
      #   response = Report.new(result).parse_data
      #   # puts result
      #   # puts response
      #   expect(response.length).to eq(1642)
      #   doi_instances =response.select {|instance| instance.dig("obj-id") == "https://doi.org/10.7272/q6qn64nk" }
      #   total_requests_regular = doi_instances.select {|instance| instance.dig("relation-type-id") == "total-dataset-requests-regular"}
      #   expect(total_requests_regular.first.dig("total")).to eq(1083)
      # end
    end 
  end

  describe "decode_report" do
    context "when there is ONE message" do
      it "should return the data for one message" do
        # expect(response.body["data"]["report"]["report-header"]["report-name"]).to eq("Dataset Master Report")
      end
    end
  end

  describe "correct_checksum" do
    context "when there is ONE message" do
      it "should return the data for one message" do
        # expect(response.body["data"]["report"]["report-header"]["report-name"]).to eq("Dataset Master Report")
      end
    end
  end

  describe "initialize" do
    let(:body)     {File.read(fixture_path + 'resolution_compress_small.json')}
    let(:response) {OpenStruct.new(body:  JSON.parse(body) )}


    context "good compressed report" do
      let(:report) {Report.new(response)}
      it "initilialise correctly" do
        # puts report.inspect
        # expect(report.data).not_empty?
        # expect(report.header).not_empty?
        # expect(report.encoded_report).not_empty?
        # expect(report.report_id).not_empty?
        # expect(report.checksum).not_empty?
        # expect(report.error).to be_empty?
      end
    end
  end

  describe "parse_report_datasets" do
    context "when there is ONE message" do
      it "should return the data for one message" do
        # expect(response.body["data"]["report"]["report-header"]["report-name"]).to eq("Dataset Master Report")
      end
    end
  end
end