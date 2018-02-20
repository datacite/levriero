require 'rails_helper'

describe 'Clients', type: :request, elasticsearch: true  do
  let(:parameters) { ActionController::Parameters.new(id: "abc.def", symbol: "ABC.DEF", name: "Test", contact_name: "Josiah Carberry", contact_email: "josiah@example.org", created: Time.zone.now) }
  let!(:client) { Client.create(parameters.permit(Client.safe_params)) }
  let(:params) do
    { "data" => { "type" => "clients",
                  "attributes" => {
                    "symbol" => client.symbol,
                    "name" => "Imperial College",
                    "contact-name" => "Madonna",
                    "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
                    "contact-email" => "bob@example.com" },
                    "relationships" => {
                			"provider" => {
                				"data" => {
                					"type" => "providers",
                					"id" => "ABC"
                				}
                			}
                		}} }
  end
  let(:headers) { {'ACCEPT'=>'application/vnd.api+json', 'CONTENT_TYPE'=>'application/vnd.api+json', 'Authorization' => 'Bearer ' + User.generate_token}}

  # describe 'GET /clients' do
  #   before do
  #     get '/clients', headers: headers
  #   end
  #
  #   it 'returns clients' do
  #     expect(json).not_to be_empty
  #     expect(json['data'].size).to eq(10)
  #     expect(response).to have_http_status(200)
  #   end
  # end

  describe 'GET /clients/:id' do
    before do
      get "/clients/#{client.symbol}", headers: headers
    end

    # context 'when the record exists' do
    #   it 'returns the client' do
    #     expect(response).to have_http_status(200)
    #     expect(json.dig('data', 'attributes', 'name')).to eq(client.name)
    #   end
    # end

    context 'when the record does not exist' do
      before { get "/clients/xxx", headers: headers }

      it 'returns a not found message' do
        expect(response).to have_http_status(404)
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
      end
    end
  end

  describe 'POST /clients' do
    # context 'when the request is valid' do
    #   before do
    #      post '/clients', params: params.to_json, headers: headers
    #   end
    #   it 'creates a client' do
    #     expect(response).to have_http_status(201)
    #     expect(json.dig('data', 'attributes', 'name')).to eq("Imperial College")
    #   end
    # end

    # context 'when the the resource exist already' do
    #   before do
    #     post '/clients', params: client.to_jsonapi.to_json, headers: headers
    #   end
    #
    #   it 'returns status code 422' do
    #     expect(response).to have_http_status(422)
    #   end
    # end
  end

  # describe 'PUT /clients/:id' do
  #   context 'when the record exists' do
  #     let(:params) do
  #       { "data" => { "type" => "clients",
  #                     "attributes" => {
  #                       "contact_email" => "bob@example.com",
  #                       "contact_name" => "sugar Juanm",
  #                       "symbol" => client.symbol,
  #                       "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
  #                       "name" => "Imperial College 2"}} }
  #     end
  #
  #     before do
  #       put "/clients/#{client.symbol}", params: params.to_json, headers: headers
  #     end
  #
  #     it 'updates the record' do
  #       expect(json.dig('data', 'attributes', 'name')).to eq("Imperial College 2")
  #       expect(json.dig('data', 'attributes', 'name')).not_to eq(client.contact_email)
  #       expect(response).to have_http_status(200)
  #     end
  #   end
  # end

  describe 'DELETE /clients/:id' do
    # before do
    #   delete "/clients/#{client.symbol}", headers: headers
    # end
    #
    # it 'returns status code 204' do
    #   expect(response).to have_http_status(204)
    # end

    context 'when the resources doesnt exist' do
      before { delete '/clients/xxx', params: params.to_json, headers: headers }

      it 'returns status code 404' do
        expect(response).to have_http_status(404)
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
      end
    end
  end
end
