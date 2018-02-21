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
end
