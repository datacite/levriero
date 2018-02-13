require 'rails_helper'

RSpec.describe "Providers", type: :request, elasticsearch: true do
  # initialize test data
  let!(:providers)  { build_list(:provider, 10) }
  let!(:provider)   { providers.first }
  let(:params) do
    { "data" => { "type" => "providers",
                  "attributes" => {
                    "symbol" => "BL",
                    "name" => "British Library",
                    "contact_email" => "bob@example.com",
                    "country_code" => "GB" } } }
  end
  let(:headers) { {'ACCEPT'=>'application/vnd.api+json', 'CONTENT_TYPE'=>'application/vnd.api+json', 'Authorization' => 'Bearer ' +  User.generate_token } }

  # # Test suite for GET /providers
  describe 'GET /providers' do
    # make HTTP get request before each example
    before do  
      providers.each {|provider| post '/providers', params: provider.to_jsonapi.to_json, headers: headers  }
      sleep 1
      get '/providers', headers: headers 
    end

    it 'returns providers' do
      expect(json).not_to be_empty
      expect(json['data'].size).to eq(10)
      expect(response).to have_http_status(200)
    end
  end

  # Test suite for GET /providers/:id
  describe 'GET /providers/:id' do
    before do
      post '/providers', params: provider.to_jsonapi.to_json, headers: headers 
      sleep 1
      get "/providers/#{provider.symbol}" , headers: headers
    end
    # context 'when the record exists' do
    #   it 'returns the provider' do
    #     expect(json).not_to be_empty
    #     expect(json['data']['id']).to eq(provider.symbol.downcase)
    #     expect(response).to have_http_status(200)
    #   end
    # end

    context 'when the record does not exist' do
      before { get "/providers/xxx" , headers: headers}

      it 'returns a not found message' do
        expect(response).to have_http_status(404)
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
      end
    end
  end
  
  # Test suite for POST /providers
  describe 'POST /providers' do
    context 'when the request is valid' do
      let(:params) do
        { "data" => { "type" => "providers",
                      "attributes" => {
                        "symbol" => "BL",
                        "name" => "British Library",
                        "region" => "EMEA",
                        "contact_email" => "doe@joe.joe",
                        "contact_name" => "timAus",
                        "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
                        "year" => "2008",
                        "country-code" => "GB" } } }
      end
      before do
         post '/providers', params: params.to_json, headers: headers 
      end
  
      it 'creates a provider' do
        expect(json.dig('data', 'attributes', 'contact-email')).to eq("doe@joe.joe")
        expect(response).to have_http_status(201)
      end
    end
  
    context 'when the request is missing a required attribute' do
      let(:params) do
        { "data" => { "type" => "providers",
                      "attributes" => {
                        "symbol" => "BL",
                        "name" => "British Library",
                        "contact_name" => "timAus",
                        "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
                        "country_code" => "GB" } } }
      end
  
      before { post '/providers', params: params.to_json, headers: headers }
  
      it 'returns a validation failure message' do
        expect(response).to have_http_status(422)
        expect(json["errors"].first).to eq("id"=>"contact_email", "title"=>"Contact email can't be blank")
      end
    end
  
    context 'when the request is missing a data object' do
      let(:params) do
        { "type" => "providers",
          "attributes" => {
            "symbol" => "BL",
            "contact_name" => "timAus",
            "name" => "British Library",
            "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
            "country_code" => "GB" } }
      end
  
      before { post '/providers', params: params.to_json, headers: headers }
  
      it 'returns status code 500' do
        expect(response).to have_http_status(500)
      end
  
      # it 'returns a validation failure message' do
      #   puts json
      #   expect(response["exception"]).to eq("#<JSON::ParserError: You need to provide a payload following the JSONAPI spec>")
      # end
    end
  end
  #
  # # Test suite for PUT /providers/:id
  describe 'PUT /providers/:id' do
    context 'when the record exists' do
      let(:params) do
        { "data" => { "type" => "providers",
                      "attributes" => {
                        "name" => "British Library",
                        "region" => "Americas",
                        "symbol" => provider.symbol,
                        "contact_email" => "Pepe@mdm.cod",
                        "contact_name" => "timAus",
                        "country_code" => "GB" } } }
      end
      before do
         post '/providers', params: provider.to_jsonapi.to_json, headers: headers
         sleep 1
         put "/providers/#{provider.symbol}", params: params.to_json, headers: headers 
         sleep 1
      end
  
      it 'updates the record' do
        expect(json.dig('data', 'attributes', 'contact-name')).to eq("timAus")
        expect(json.dig('data', 'attributes', 'contact-email')).not_to eq(provider.contact_email)
        expect(response).to have_http_status(200)
      end
  
      context 'when the resources doesnt exist' do
        let(:params) do
          { "data" => { "type" => "providers",
                        "attributes" => {
                          "name" => "British Library",
                          "region" => "Americas",
                          "contact_email" => "Pepe@mdm.cod",
                          "contact_name" => "timAus",
                          "country_code" => "GB" } } }
        end
  
        before { put '/providers/xxx', params: params.to_json, headers: headers }
  
        it 'returns status code 404' do
          expect(response).to have_http_status(404)
        end
      end
    end
  end
  #
  # # Test suite for DELETE /providers/:id
  # describe 'DELETE /providers/:id' do
  #   before { delete "/providers/#{provider.symbol}", headers: headers }
  #
  #   it 'returns status code 204' do
  #     expect(response).to have_http_status(204)
  #   end
  #   context 'when the resources doesnt exist' do
  #     before { delete '/providers/xxx', params: params.to_json, headers: headers }
  #
  #     it 'returns status code 404' do
  #       expect(response).to have_http_status(404)
  #     end
  #
  #     it 'returns a validation failure message' do
  #       expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
  #     end
  #   end
  # end
end
