# require 'rails_helper'

# RSpec.describe 'ClientsController', type: :controller do
#   let(:provider) { build(:provider, symbol: "tib") }
#   let(:model) { ClientsController.new }
#   let!(:client)  { build(:client, provider_id: provider.symbol, symbol: "tib.tib") }
#   let(:params)  { {year: 2008} }
#   let(:params2)  { {year: clients.first.created.year} }

#   describe "dois_count_by_client" do

#     before do
#         Provider.create(provider)
#         Client.create(client)
#         sleep 2
#       end

#     it "should return OK response" do
#         r = model.dois_count_by_client "clients/tib.tib"

#     end
#     # it "should return formatted counts" do
#     #   client = clients.first
#     #   facet = model.client_year_facet params2, Client
#     #   expect(facet.first[:count]).to eq(5)
#     # end
#   end
# end

# # RSpec.describe 'ProvidersController', type: :controller do
# #     let(:provider) { create(:provider) }
# #     let(:model) { DataCentersController.new }
# #     let!(:clients)  { create_list(:client, 5, provider: provider) }
# #     let(:params)  { {year: 2008} }
# #     let(:params2)  { {year: clients.first.created.year} }

# #     describe "dois_count_by_client" do
# #         it "should return OK response" do
# #             facet = model.client_year_facet params, Client
# #             expect(facet.first[:count]).to eq(0)
# #         end
# #         it "should return formatted counts" do
# #             client = clients.first
# #             facet = model.client_year_facet params2, Client
# #             expect(facet.first[:count]).to eq(5)
# #         end
# #     end
# # end
