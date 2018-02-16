require 'rails_helper'

RSpec.describe 'Clients', type: :request, elasticsearch: true  do
  let!(:provider) { build(:provider) }
  let!(:clients)  { build_list(:client, 10, provider_id: provider.symbol) }
  let!(:client) { clients.first }
  let(:params) do
    { "data" => { "type" => "clients",
                  "attributes" => {
                    "symbol" => provider.symbol+".IMPERIAL",
                    "name" => "Imperial College",
                    "contact-name" => "Madonna",
                    "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
                    "contact-email" => "bob@example.com" },
                    "relationships": {
                			"provider": {
                				"data":{
                					"type":"providers",
                					"id": provider.symbol
                				}
                			}
                		}} }
  end
  let(:headers) { {'ACCEPT'=>'application/vnd.api+json', 'CONTENT_TYPE'=>'application/vnd.api+json', 'Authorization' => 'Bearer ' + User.generate_token}}
  let(:query) { "jamon"}

  # Test suite for GET /clients
  describe 'GET /clients' do
    before do
      Provider.create(provider)         
      clients.each {|client| post '/clients', params: client.to_jsonapi.to_json, headers: headers  }
      # dois.each   { |item| Doi.create(item) }
      sleep 2 
      get '/clients', headers: headers 
    end

    it 'returns clients' do
      expect(json).not_to be_empty
      expect(json['data'].size).to eq(10)
      expect(response).to have_http_status(200)
    end
  end

  # # Test suite for GET /clients
  # describe 'GET /clients query' do
  #   before { get "/clients?query=#{query}", headers: headers }
  #
  #   it 'returns clients' do
  #     expect(json).not_to be_empty
  #     expect(json['data'].size).to eq(11)
  #   end
  #
  #   it 'returns status code 200' do
  #     expect(response).to have_http_status(200)
  #   end
  # end

  # Test suite for GET /clients/:id
  describe 'GET /clients/:id' do
    before do
      post '/clients', params: client.to_jsonapi.to_json, headers: headers 
      sleep 2
      get "/clients/#{client.symbol}", headers: headers 
    end

    context 'when the record exists' do
      it 'returns the client' do
        # puts client.inspect
        puts json.inspect
        expect(response).to have_http_status(200)
        expect(json).not_to be_empty
        expect(json.dig('data', 'attributes', 'name')).to eq(client.name)
      end
    end

    context 'when the record does not exist' do
      before { get "/clients/xxx", headers: headers }

      it 'returns a not found message' do
        expect(response).to have_http_status(404)
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
      end
    end
  end

  # Test suite for POST /clients
  describe 'POST /clients' do
    context 'when the request is valid' do
      before do
         post '/clients', params: params.to_json, headers: headers 
         sleep 1 
      end
      it 'creates a client' do
        expect(response).to have_http_status(201)
        expect(json.dig('data', 'attributes', 'name')).to eq("Imperial College")
      end
    end

    # context 'when the request is invalid' do
    #   let(:params) do
    #     { "data" => { "type" => "clients",
    #                   "attributes" => {
    #                     "symbol" => provider.symbol+".IMPERIAL",
    #                     "name" => "Imperial College"},
    #                     "contact-name" => "Madonna",
    #                     "created" => "2017-08-29T06:54:15Z" ,
    #                     "relationships": {
    #                 			"provider": {
    #                 				"data":{
    #                 					"type": "providers",
    #                 					"id": provider.symbol
    #                 				}
    #                 			}
    #                 		}} }
    #   end

    #   before do
    #      post '/clients', params: params.to_json, headers: headers 
    #      sleep 1
    #   end

    #   it 'returns a validation failure message' do
    #     expect(response).to have_http_status(422)
    #     expect(json["errors"].first).to eq("id"=>"contact-email", "title"=>"Contact email can't be blank")
    #   end
    # end

    context 'when the the resource exist already' do
      before do
         post '/clients', params: client.to_jsonapi.to_json, headers: headers 
         sleep 1
         post '/clients', params: client.to_jsonapi.to_json, headers: headers 
         sleep 1
      end
  
      it 'returns status code 422' do
        expect(response).to have_http_status(422)
      end
  
      # it 'returns a validation failure message' do
      #   puts json
      #   expect(response["exception"]).to eq("#<JSON::ParserError: You need to provide a payload following the JSONAPI spec>")
      # end
    end
  end

  # # Test suite for PUT /clients/:id
  describe 'PUT /clients/:id' do
    context 'when the record exists' do
      let(:params) do
        { "data" => { "type" => "clients",
                      "attributes" => {
                        "contact_email" => "bob@example.com",
                        "contact_name" => "sugar Juanm",
                        "symbol" => client.symbol,
                        "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
                        "name" => "Imperial College 2"}} }
      end
      before do
        post '/clients', params: client.to_jsonapi.to_json, headers: headers
        sleep 1
        put "/clients/#{client.symbol}", params: params.to_json, headers: headers 
        sleep 2
     end
      it 'updates the record' do
        expect(json.dig('data', 'attributes', 'name')).to eq("Imperial College 2")
        expect(json.dig('data', 'attributes', 'name')).not_to eq(client.contact_email)
        expect(response).to have_http_status(200)
      end
    end

    context 'when the changeing symbol' do
      let(:params) do
        { "data" => { "type" => "clients",
                      "attributes" => {
                        "name" => "British Library",
                        "region" => "Americas",
                        "symbol" => client.symbol,
                        "contact-email" => "Pepe@mdm.cod",
                        "contact-name" => "timAus",
                        "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
                        "country_code" => "GB" } } }
      end
      let(:params2) do
        { "data" => { "type" => "clients",
                      "attributes" => {
                        "name" => "British Library",
                        "region" => "Americas",
                        "symbol" => "RainbowDash",
                        "contact-email" => "Pepe@mdm.cod",
                        "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
                        "contact-name" => "timAus",
                        "country_code" => "GB" } } }
      end

      before do
        post '/clients', params: params.to_json, headers: headers
        sleep 1
        put "/clients/#{client.symbol}", params: params2.to_json, headers: headers 
        sleep 1
     end  
      it 'returns status code 422' do
        expect(response).to have_http_status(422)
        expect(json["errors"].first).to eq("status"=>"422", "title"=>"Symbol cannot be changed")
      end
    end
  end

  # Test suite for DELETE /clients/:id
  describe 'DELETE /clients/:id' do
    before do
      post '/clients', params: client.to_jsonapi.to_json, headers: headers
      sleep 2
      delete "/clients/#{client.symbol}", headers: headers 
      sleep 1
    end

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
