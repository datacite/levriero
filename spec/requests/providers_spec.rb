require 'rails_helper'

describe "Providers", type: :request, elasticsearch: true, vcr: true do
  let(:parameters) { ActionController::Parameters.new(id: "abc", symbol: "ABC", name: "Test", contact_name: "Josiah Carberry", contact_email: "josiah@example.org", created: Time.zone.now) }
  let!(:provider) { Provider.create(parameters.permit(Provider.safe_params)) }
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
  # describe 'GET /providers' do
  #   before do
  #     get '/providers', headers: headers
  #   end
  #
  #   it 'returns providers' do
  #     expect(json['data'].size).to eq(25)
  #     expect(response).to have_http_status(200)
  #   end
  # end

  describe 'GET /providers/:id' do
    # before do
    #   get "/providers/#{provider.symbol}" , headers: headers
    # end
    #
    # context 'when the record exists' do
    #   it 'returns the provider' do
    #     expect(response.body).not_to be_empty
    #     expect(json['data']).to eq(provider.symbol.downcase)
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
                        "created" => "2017-08-29T06:54:15Z" ,
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
                        "symbol" => "BLS",
                        "name" => "British Library",
                        "contact_name" => "timAus",
                        "created" =>"2017-08-29T06:54:15Z" ,
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

      # it 'returns status code 500' do
      #   expect(response).to have_http_status(500)
      # end

      it 'returns a validation failure message' do
        expect(json["errors"].first).to eq("status"=>"400", "title"=>"You need to provide a payload following the JSONAPI spec")
      end
    end

    # context 'when the the resource exist already' do
    #   before do
    #      post '/providers', params: provider.to_jsonapi.to_json, headers: headers
    #   end
    #
    #   it 'returns status code 422' do
    #     puts json
    #     expect(response).to have_http_status(422)
    #   end
    #
    #   it 'returns a validation failure message' do
    #     expect(response).to have_http_status(422)
    #     expect(json["errors"].first).to eq("id"=>"contact_email", "title"=>"Contact email can't be blank")
    #   end
    # end
  end

  describe 'PUT /providers/:id' do
    context 'when the record exists' do
    #   let(:params) do
    #     { "data" => { "type" => "providers",
    #                   "attributes" => {
    #                     "name" => "British Library",
    #                     "region" => "Americas",
    #                     "symbol" => provider.symbol,
    #                     "contact_email" => "Pepe@mdm.cod",
    #                     "contact_name" => "timAus",
    #                     "country_code" => "GB" } } }
    #   end
    #
    #   before do
    #      put "/providers/#{provider.symbol}", params: params.to_json, headers: headers
    #   end
    #
    #   it 'updates the record' do
    #     expect(json.dig('data', 'attributes', 'contact-name')).to eq("timAus")
    #     expect(json.dig('data', 'attributes', 'contact-email')).not_to eq(provider.contact_email)
    #     expect(response).to have_http_status(200)
    #   end

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

  describe 'DELETE /providers/:id' do
    # before { delete "/providers/#{provider.symbol}", headers: headers }
    #
    # it 'returns status code 204' do
    #   expect(response).to have_http_status(204)
    # end

    context 'when the resources doesnt exist' do
      before { delete '/providers/xxx', headers: headers }

      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end

      it 'returns a validation failure message' do
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
      end
    end
  end
end
