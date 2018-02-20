require 'rails_helper'

describe "Importable", type: :model, vcr: true do
  describe "import_from_api" do
    # return number of clients or providers imported into Elasticsearch
    it "client" do
      expect(Client.import_from_api).to eq(1439)
    end

    it "provider" do
      expect(Provider.import_from_api).to eq(67)
    end
  end
end
