require "rails_helper"

describe "Clients", elasticsearch: true, type: :controller do
  # let!(:provider) { build(:provider) }
  # let(:model) { ClientsController.new }
  # let!(:clients)  { build_list(:client, 5, provider_id: provider) }
  # let!(:params)  { {year: 2001} }
  # let!(:params2)  { {year: clients.first.created.year} }
  # let!(:params3)  { {year: nil} }
  # let!(:ids)  { clients.first.symbol+","+clients.last.symbol }

  # describe "facet by year" do
  #   # context "this" do
  #     before do
  #       Provider.create(provider)
  #       clients.each { |item| Client.create(item) }
  #       # dois.each   { |item| Doi.create(item) }
  #       sleep 2
  #     end
  #     it "should return nothing" do
  #       puts Client.all
  #       facet = model.facet_by_year params, Client.all
  #       puts facet.class.name
  #       puts facet.inspect
  #       puts "chchc"
  #       expect(facet.first[:count]).to eq(0)
  #     end
  #     it "should return all records" do
  #       facet = model.facet_by_year params2, Client.all
  #       puts facet
  #       expect(facet.first[:count]).to eq(5)
  #     end
  #     it "should return all records for nothing" do
  #       cc= Client.all.to_enum(:each)
  #       facet = model.facet_by_year params3, cc
  #       puts facet
  #       expect(facet.first[:count]).to eq(5)
  #     end
  #   # end
  # end

  # describe "filter_by_ids" do
  #   context "this" do
  #     before do
  #       Provider.create(provider)
  #       clients.each { |item| Client.create(item) }
  #       # dois.each   { |item| Doi.create(item) }
  #       sleep 1
  #     end
  #     it "should return 2 from unfiltered" do
  #       puts ids
  #       # puts Client.all
  #       filtered = model.filter_by_ids ids, Client
  #       puts filtered.inspect
  #       expect(filtered.count).to eq(2)
  #       expect(filtered.class).to eq(Enumerator)
  #     end
  #     it "should return 2 from filtered" do
  #       # puts ids
  #       # enumerator = Client.all.to_enum(:each)
  #       # filtered = model.filter_by_ids ids, enumerator
  #       # puts filtered.class.name
  #       # expect(filtered.count).to eq(2)
  #       # expect(filtered.class).to eq(Enumerator)
  #     end
  #   end
  # end
end
