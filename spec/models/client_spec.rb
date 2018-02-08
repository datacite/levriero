require 'rails_helper'
WebMock.enable!
include WebMock::API

RSpec.describe Client, elasticsearch: true, type: :model do
  let!(:provider)    { build(:provider) }  
  let!(:clients)     { build_list(:client, 25, provider_id: provider.symbol) }
  let!(:client)      { clients.first }
  # let!(:dois)        { build_list(:doi, 10, client_id: client.symbol) }  
  let!(:client_last) { clients.last }


  describe "List Clients" do
    context "when there are clients" do 
      before do 
        Provider.create(provider)         
        clients.each { |item| Client.create(item) }
        # dois.each   { |item| Doi.create(item) }
        sleep 2
      end

      it "returns all clients" do
        collection = Client.all
        expect(collection.length).to eq(clients.length)
      end

      it "returns correct attributes", :skip => true do
        # puts Client.all
        single = Client.query_filter_by(:symbol, client.symbol).first
        # puts single.inspect
        # puts client.symbol.downcase
        expect(single.name).to eq(client.name)
        expect(single.role_name).to eq(client.role_name)
      end

      it "returns correct number of clients" do
        single = Client.query_filter_by(:symbol, client.symbol).first
        # client_count = single.doi_count
        # expect(doi_count.first[:count]).to eq(clients.length)
      end
    end

    context "when there are not clients" do 

      it "returns no clients" do
        # collection = Client.all
        # expect(collection.length).to eq(0)
      end
    end
  end

  describe "Show Client" do
    context "when the client exist" do 
      before do 
        Provider.create(provider)                 
        Client.create(client) 
        sleep 2
      end

      it "returns correct attributes" do

        single = Client.query_filter_by(:symbol, client.symbol).first
        expect(single.name).to eq(client.name)
        expect(single.symbol).to eq(client.symbol)
        expect(single.role_name).to eq(client.role_name)
        expect(single.created).to be_truthy
        expect(single.updated).to be_truthy
        # expect(single.region).to be_truthy
        expect(single.is_active).to be_truthy
        expect(single.doi_quota_allowed).to be_truthy
        expect(single.doi_quota_used).to be_truthy
      end
    end
    context "when the client do not exist" do 
      before do 
        clients.each { |item| Client.create(item) }
        sleep 2
      end

      it "returns no attributes" do
        single = Client.query_filter_by(:symbol, client.symbol).first
        expect(single.name).not_to eq(client_last.name)
        expect(single.symbol).not_to eq(client_last.symbol)
      end
    end
  end

  describe "Create Client" do
    context "when the client do not exist" do 
      before do 
        Provider.create(provider)                 
        Client.create(client) 
        sleep 2
      end

      it "returns correct attributes" do
        single = Client.query_filter_by(:symbol, client.symbol).first
        expect(single.name).to eq(client.name)
        expect(single.symbol).to eq(client.symbol)
        expect(single.role_name).to eq(client.role_name)
        expect(single.created).to be_truthy
        expect(single.updated).to be_truthy
        # expect(single.region).to be_truthy
        expect(single.is_active).to be_truthy
        expect(single.doi_quota_allowed).to be_truthy
        expect(single.doi_quota_used).to be_truthy
      end
    end
    context "when the client  exist" do 
      before do 
        Provider.create(provider)                 
        Client.create(client) 
        sleep 2
        Client.create(client) 
        sleep 2
      end

      it "returns correct attributes" do
        prov = Client.query_filter_by(:symbol, client.symbol).count
        expect(prov).to eq(2)
      end
    end
  end

  describe "Update Client" do
    context "when parameter are correct" do 
      before do 
        pv = Client.create(client) 
        sleep 2
        pv.update_attributes name: "Logan"
        sleep 2      
      end

      it "returns correct attributes" do
        single = Client.query_filter_by(:symbol, client.symbol).first
        expect(single.name).not_to eq(client.name)
        expect(single.symbol).to eq(client.symbol)
        expect(single.role_name).to eq(client.role_name)
        expect(single.created).to be_truthy
      end
    end
  end

  describe "Delete Client" do
    context "when the client exist" do 
      before do 
        Provider.create(provider)                 
        pv = Client.create(client) 
        sleep 2 
        pv.destroy
        sleep 2
      end

      it "returns correct response" do
        single = Client.query_filter_by(:symbol, client.symbol).first
        expect(single.respond_to?(:name)).to be false
      end
    end

    context "when the client do not exist" do 
      before do 
        Provider.create(provider)                 
        Client.create(client) 
        sleep 2 
      end

      it "returns correct attributes" do

      end
    end
  end

  # describe "Query Client" do
  #   context "when the client exist" do 
  #     before do 
  #       clients.each { |item| Client.create(item) }
  #       sleep 2         
  #     end

  #     it "returns correct attributes" do
  #       collection = Client.query(client.name)
  #       results = collection.select { |item| item.symbol.casecmp client.symbol }
  #       expect(results.length).to be > 0 
  #       expect(results.length).to be < clients.length
  #       expect(collection.first.respond_to?(:name)).to be true
  #     end
  #   end
  #   context "when the client do not exist" do 
  #     before do 
  #       clients.each { |item| Client.create(item) }
  #       sleep 2 
  #     end

  #     it "returns correct attributes" do
  #       single = Client.query("TIB").first
  #       expect(single.respond_to?(:name)).to be false        
  #     end
  #   end
  # end

  

end
