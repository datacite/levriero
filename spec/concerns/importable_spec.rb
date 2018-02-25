require 'rails_helper'

describe "Importable", elasticsearch: true, vcr: true do
  context "Client" do
    describe "import_from_api" do
      # return number of clients or providers imported into Elasticsearch
      it "import" do
        expect(Client.import_from_api).to eq(0)
      end
    end

    describe "import_record" do
      let(:client) { create(:client) }
      let(:data_for_client) { { "id" => client.attributes[:symbol].downcase, "type" => "clients", "attributes" => client.attributes.except(:id, :created_at, :updated_at) } }
      let(:attributes) { attributes_for(:client) }
      let(:data) { { "id" => attributes["id"], "type" => "clients", "attributes" => attributes } }

      it "create" do
        client = Client.import_record(data)
        expect(client).to be_valid
      end

      it "update" do
        client = Client.import_record(data_for_client)
        expect(client).to be_valid
      end

      it "update invalid" do
        data_for_client["attributes"][:contact_email] = nil
        client = Client.import_record(data_for_client)
        expect(client).not_to be_valid
        expect(client.errors.to_a).to eq(["Contact email can't be blank"])
      end
    end

    describe "create_record" do
      let(:attributes) { attributes_for(:client) }

      it "valid" do
        client = Client.create_record(attributes)
        expect(client).to be_valid
      end

      it "missing attribute" do
        client = Client.create_record(attributes.except(:contact_email))
        expect(client).not_to be_valid
        expect(client.errors.to_a).to eq(["Contact email can't be blank"])
      end
    end

    describe "update_record" do
      let(:client) { create(:client) }

      it "valid" do
        attributes = { "contact_email" => "info@example.org" }
        client.update_record(attributes)
        expect(client).to be_valid
        expect(client.contact_email).to eq("info@example.org")
      end

      it "missing attribute" do
        attributes = { "contact_email" => nil }
        client.update_record(attributes)
        expect(client).not_to be_valid
        expect(client.errors.to_a).to eq(["Contact email can't be blank"])
      end
    end

    describe "delete_record" do
      let(:client) { create(:client) }

      it "valid" do
        client.delete_record
        expect(client.destroyed?).to be true
      end
    end
  end

  context "Provider" do
    describe "import_from_api" do
      it "import" do
        expect(Provider.import_from_api).to eq(67)
      end
    end

    describe "import_record" do
      let(:provider) { create(:provider) }
      let(:data_for_provider) { { "id" => provider.attributes[:symbol].downcase, "type" => "providers", "attributes" => provider.attributes.except(:id, :created_at, :updated_at) } }
      let(:attributes) { attributes_for(:provider) }
      let(:data) { { "id" => attributes["id"], "type" => "providers", "attributes" => attributes } }

      it "create" do
        provider = Provider.import_record(data)
        expect(provider).to be_valid
      end

      it "update" do
        provider = Provider.import_record(data_for_provider)
        expect(provider).to be_valid
      end

      it "update invalid" do
        data_for_provider["attributes"][:contact_email] = nil
        provider = Provider.import_record(data_for_provider)
        expect(provider).not_to be_valid
        expect(provider.errors.to_a).to eq(["Contact email can't be blank"])
      end
    end

    describe "create_record" do
      let(:attributes) { attributes_for(:provider) }

      it "valid" do
        provider = Provider.create_record(attributes)
        expect(provider).to be_valid
      end

      it "missing attribute" do
        provider = Provider.create_record(attributes.except(:contact_email))
        expect(provider).not_to be_valid
        expect(provider.errors.to_a).to eq(["Contact email can't be blank"])
      end
    end

    describe "update_record" do
      let(:provider) { create(:provider) }

      it "valid" do
        attributes = { "contact_email" => "info@example.org" }
        provider.update_record(attributes)
        expect(provider).to be_valid
        expect(provider.contact_email).to eq("info@example.org")
      end

      it "missing attribute" do
        attributes = { "contact_email" => nil }
        provider.update_record(attributes)
        expect(provider).not_to be_valid
        expect(provider.errors.to_a).to eq(["Contact email can't be blank"])
      end
    end

    describe "delete_record" do
      let(:provider) { create(:provider) }

      it "valid" do
        provider.delete_record
        expect(provider.destroyed?).to be true
      end
    end
  end

  describe "to_kebab_case" do
    it "converts" do
      hsh = { "provider-id" => "bl", "country-code" => "GB" }
      expect(Client.to_kebab_case(hsh)).to eq("provider_id"=>"bl", "country_code"=>"GB")
    end
  end
end
