require 'rails_helper'

describe Report, type: :model do
  let(:body)     {File.read(fixture_path + 'resolution_compress_small.json')}
  let(:response) {OpenStruct.new(body:  JSON.parse(body) )}
  let(:report)   {Report.new(response)}



  describe "decompress_report" do
    context "when there is ONE message" do

      it "should return the data for one message" do
        # puts report
        # expect(report.decode_report).to eq(ActiveSupport::Gzip.decompress(Base64.decode64(response.dig("data","report","gzip"))))
      end
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