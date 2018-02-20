require 'rails_helper'

describe Provider, elasticsearch: true, type: :model do
  let(:attributes) { ActionController::Parameters.new(symbol: "ABC", name: "Test", contact_name: "Josiah Carberry", contact_email: "josiah@example.org") }

  describe "validations" do
    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:contact_email) }
    it { should validate_presence_of(:contact_name) }
  end

  describe "country code" do
    it "set country and region" do
      attributes.merge!(country_code: "AU")
      provider = Provider.new(attributes.permit(Provider.safe_params))
      expect(provider.country_name).to eq("Australia")
      expect(provider.region).to eq("APAC")
      expect(provider.region_name).to eq("Asia Pacific")
    end

    it "missing country code" do
      provider = Provider.new(attributes.permit(Provider.safe_params))
      expect(provider.country_name).to be_nil
      expect(provider.region).to be_nil
      expect(provider.region_name).to be_nil
    end
  end
end
