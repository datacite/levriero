# require 'rails_helper'
#
# describe ClientsController, type: :controller do
#
#   let(:valid_attributes) {
#     skip("Add a hash of attributes valid for your model")
#   }
#
#   let(:invalid_attributes) {
#     skip("Add a hash of attributes invalid for your model")
#   }
#
#   let(:valid_session) { {} }
#
#   describe "GET #index" do
#     it "returns a success response" do
#       client = Client.create! valid_attributes
#       get :index, params: {}, session: valid_session
#       expect(response).to be_success
#     end
#   end
#
#   describe "GET #show" do
#     it "returns a success response" do
#       client = Client.create! valid_attributes
#       get :show, params: {id: client.to_param}, session: valid_session
#       expect(response).to be_success
#     end
#   end
#
#   describe "POST #create" do
#     context "with valid params" do
#       it "creates a new Client" do
#         pending("something else getting finished")
#         expect {
#           post :create, params: {client: valid_attributes}, session: valid_session
#         }.to change(Client, :count).by(1)
#       end
#
#       it "renders a JSON response with the new client" do
#         pending("something else getting finished")
#         post :create, params: {client: valid_attributes}, session: valid_session
#         expect(response).to have_http_status(:created)
#         expect(response.content_type).to eq('application/json')
#         expect(response.location).to eq(client_url(Client.last))
#       end
#     end
#   end
# end
