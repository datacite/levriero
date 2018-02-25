require 'rails_helper'

describe Client, elasticsearch: true, type: :model do
  describe "validations" do
    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:contact_email) }
    it { should validate_presence_of(:contact_name) }
  end

  describe "uniqueness" do
    let(:client) { build(:client, symbol: "BL.CDCC") }

    it "validates" do
      expect(client).to be_valid
    end

    it "does not validate" do
      create(:client, symbol: "BL.CDCC")
      expect(client).not_to be_valid
      expect(client.errors.to_a).to eq(["Symbol This ID has already been taken"])
    end
  end

  describe "to_jsonapi" do
    let(:client) { create(:client) }

    it "works" do
      params = client.to_jsonapi
      expect(params.dig("id")).to eq(client.symbol.downcase)
      expect(params.dig("attributes","symbol")).to eq(client.symbol)
      expect(params.dig("attributes","contact-email")).to eq(client.contact_email)
      expect(params.dig("attributes","provider-id")).to eq(client.provider_id)
      expect(params.dig("attributes","is-active")).to be true
    end
  end
end
