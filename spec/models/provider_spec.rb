require 'rails_helper'

describe Provider, elasticsearch: true, type: :model do
  describe "validations" do
    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:contact_email) }
    it { should validate_presence_of(:contact_name) }
  end

  describe "uniqueness" do
    let(:provider) { build(:provider, id: "bl") }

    it "validates" do
      expect(provider).to be_valid
    end

    it "does not validate" do
      create(:provider, id: "bl")
      expect(provider).not_to be_valid
      expect(provider.errors.to_a).to eq(["Symbol This ID has already been taken"])
    end
  end

  describe "country code" do
    let(:provider) { build(:provider, country_code: "AU") }

    it "set country and region" do
      expect(provider.country_name).to eq("Australia")
      expect(provider.region).to eq("APAC")
      expect(provider.region_name).to eq("Asia Pacific")
    end

    it "missing country code" do
      provider = build(:provider, country_code: nil)
      expect(provider.country_name).to be_nil
      expect(provider.region).to be_nil
      expect(provider.region_name).to be_nil
    end
  end
end
