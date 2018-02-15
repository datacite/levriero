require 'rails_helper'

RSpec.describe Provider, elasticsearch: true, type: :model do
  let!(:providers)     { build_list(:provider, 25) }
  let!(:provider)      { providers.first }
  let!(:clients)        { build_list(:client, 10, provider_id: provider.symbol) }  
  let!(:provider_last) { providers.last }


  describe "List Providers" do
    context "when there are providers" do 
      before do 
        providers.each { |item| Provider.create(item) }
        clients.each   { |item| Client.create(item) }
        sleep 2
      end

      it "returns all providers" do
        collection = Provider.all
        expect(collection.length).to eq(providers.length)
      end

      it "returns correct attributes" do
        single = Provider.query_filter_by(:symbol, provider.symbol).first
        expect(single.name).to eq(provider.name)
        expect(single.role_name).to eq(provider.role_name)
      end

      it "returns correct number of clients" do
        single = Provider.query_filter_by(:symbol, provider.symbol).first
        client_count = single.client_count
        expect(client_count.first[:count]).to eq(clients.length)
      end
    end

    context "when there are not providers" do 

      it "returns no providers" do
        # collection = Provider.all
        # expect(collection.length).to eq(0)
      end
    end
  end

  describe "Show Provider" do
    context "when the provider exist" do 
      before do 
        Provider.create(provider) 
        sleep 2
      end

      it "returns correct attributes" do

        single = Provider.query_filter_by(:symbol, provider.symbol).first
        expect(single.name).to eq(provider.name)
        expect(single.symbol).to match(%r{#{provider.symbol}}i)
        expect(single.role_name).to eq(provider.role_name)
        expect(single.created).to be_truthy
        expect(single.updated).to be_truthy
        # expect(single.region).to be_truthy
        expect(single.is_active).to be_truthy
        expect(single.doi_quota_allowed).to be_truthy
        expect(single.doi_quota_used).to be_truthy
      end
    end
    context "when the provider do not exist" do 
      before do 
        providers.each { |item| Provider.create(item) }
        sleep 2
      end

      it "returns no attributes" do
        single = Provider.query_filter_by(:symbol, provider.symbol).first
        expect(single.name).not_to eq(provider_last.name)
        expect(single.symbol).not_to eq(provider_last.symbol)
      end
    end
  end

  describe "Create Provider" do
    context "when the provider do not exist" do 
      before do 
        Provider.create(provider) 
        sleep 2
      end

      it "returns correct attributes" do
        single = Provider.query_filter_by(:symbol, provider.symbol).first
        expect(single.name).to eq(provider.name)
        expect(single.symbol).to match(%r{#{provider.symbol}}i)
        expect(single.role_name).to eq(provider.role_name)
        expect(single.created).to be_truthy
        expect(single.updated).to be_truthy
        # expect(single.region).to be_truthy
        expect(single.is_active).to be_truthy
        expect(single.doi_quota_allowed).to be_truthy
        expect(single.doi_quota_used).to be_truthy
      end
    end
    # context "when the provider  exist" do 
    #   before do 
    #     Provider.create(provider) 
    #     sleep 2
    #     Provider.create(provider) 
    #     sleep 2
    #   end

    #   it "returns correct attributes" do
    #     prov = Provider.query_filter_by(:symbol, provider.symbol).count
    #     expect(prov).to eq(1)
    #   end
    # end
  end

  describe "Update Provider" do
    # context "when parameter are correct" do 
    #   before do 
    #     pv = Provider.create(provider) 
    #     sleep 2
    #     pv.update_attributes name: "Logan"
    #     sleep 2      
    #   end

    #   it "returns correct attributes" do
    #     single = Provider.query_filter_by(:symbol, provider.symbol).first
    #     expect(single.name).not_to eq(provider.name)
    #     expect(single.symbol).to eq(provider.symbol)
    #     expect(single.role_name).to eq(provider.role_name)
    #     expect(single.created).to be_truthy
    #   end
    # end
  end

  describe "Delete Provider" do
    context "when the provider exist" do 
      before do 
        pv = Provider.create(provider) 
        sleep 2 
        pv.destroy
        sleep 2
      end

      it "returns correct response" do
        single = Provider.query_filter_by(:symbol, provider.symbol)
        expect(single.length).to eq(0)
      end
    end

    context "when the provider do not exist" do 
      before do 
        Provider.create(provider) 
        sleep 2 
      end

      it "returns correct attributes" do

      end
    end
  end

  describe "Query Provider" do
    context "when the provider exist" do 
      before do 
        providers.each { |item| Provider.create(item) }
        sleep 2         
      end

      it "returns correct attributes" do
        collection = Provider.query(provider.name)
        results = collection.select { |item| item.symbol.casecmp provider.symbol }
        expect(results.length).to be > 0 
        expect(results.length).to be < providers.length
        expect(collection.first.respond_to?(:name)).to be true
      end
    end
    context "when the provider do not exist" do 
      before do 
        providers.each { |item| Provider.create(item) }
        sleep 2 
      end

      it "returns correct attributes" do
        single = Provider.query("TIB").first
        expect(single.respond_to?(:name)).to be false        
      end
    end

    context "when the provider exist and case insentive" do 
      before do 
        providers.each { |item| Provider.create(item) }
        sleep 2         
      end

      it "returns always the correct resource" do
        provider_r = Provider.find_by_id(provider.symbol.downcase)
        expect(provider_r.respond_to?(:symbol)).to be true
        expect(provider_r.symbol).to match(%r{#{provider.symbol}}i)

        provider_r = Provider.find_by_id(provider.symbol.upcase)
        expect(provider_r.respond_to?(:symbol)).to be true
        expect(provider_r.symbol).to match(%r{#{provider.symbol}}i)

        provider_r = Provider.find_by_id(provider.symbol)
        expect(provider_r.respond_to?(:symbol)).to be true
        expect(provider_r.symbol).to match(%r{#{provider.symbol}}i)

        provider_r = Provider.find_by_id(provider.symbol.titlecase)
        expect(provider_r.respond_to?(:symbol)).to be true
        expect(provider_r.symbol).to match(%r{#{provider.symbol}}i)
      end
    end

    context "when the provider exist and case insentive" do 
      before do 
        providers.each { |item| Provider.create(item) }
        sleep 2         
      end

      it "returns always the correct resource" do
        provider_r = Provider.query_filter_by(:symbol, provider.symbol.downcase).first
        expect(provider_r.respond_to?(:symbol)).to be true
        expect(provider_r.symbol).to match(%r{#{provider.symbol}}i)

        provider_r = Provider.query_filter_by(:symbol, provider.symbol.upcase).first
        expect(provider_r.respond_to?(:symbol)).to be true
        expect(provider_r.symbol).to match(%r{#{provider.symbol}}i)

        provider_r = Provider.query_filter_by(:symbol, provider.symbol).first
        expect(provider_r.respond_to?(:symbol)).to be true
        expect(provider_r.symbol).to match(%r{#{provider.symbol}}i)

        provider_r = Provider.query_filter_by(:symbol, provider.symbol.titlecase).first
        expect(provider_r.respond_to?(:symbol)).to be true
        expect(provider_r.symbol).to match(%r{#{provider.symbol}}i)
      end
    end

    context "when the provider exist and case insentive and incomplete" do 
      before do 
        providers.each { |item| Provider.create(item) }
        sleep 2         
      end

      it "returns always the correct resource" do
        collection = Provider.query("tes")
        expect(collection.respond_to?(:response)).to be true
        expect(collection.count).to be > 1
      end

      it "returns always the correct resource" do
        collection = Provider.query("ROGERMANANANANA")
        expect(collection.respond_to?(:response)).to be true
        expect(collection.count).to be == 0
      end
    end
  end

  

end
