require 'rails_helper'

describe "Providers", type: :request, elasticsearch: true, vcr: true do
  let(:params) do
    { "data" => { "type" => "providers",
                  "attributes" => {
                    "symbol" => "BL",
                    "name" => "British Library",
                    "contact-email" => "bob@example.com",
                    "country-code" => "GB" } } }
  end
  let(:headers) { {'ACCEPT'=>'application/vnd.api+json', 'CONTENT_TYPE'=>'application/vnd.api+json', 'Authorization' => 'Bearer ' +  User.generate_token } }

  describe 'GET /providers' do
    let!(:providers) { create_list(:provider, 3) }

    context 'sort by created' do
      before do
        sleep 1
        get '/providers?sort=created', headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'sort by created desc' do
      before do
        sleep 1
        get '/providers?sort=-created', headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'sort by name' do
      before do
        sleep 1
        get '/providers?sort=name', headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'sort by name desc' do
      before do
        sleep 1
        get '/providers?sort=-name', headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'sort default' do
      before do
        sleep 1
        get '/providers', headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'page[size]=2' do
      before do
        sleep 1
        get '/providers?page[size]=2', headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(2)
        expect(response).to have_http_status(200)
      end
    end

    context 'page[size]=100' do
      before do
        sleep 1
        get '/providers?page[size]=100', headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'page[size]=2 and page[number]=2' do
      before do
        sleep 1
        get '/providers?page[size]=2&page[number]=2', headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(1)
        expect(response).to have_http_status(200)
      end
    end

    context 'filter by year' do
      let(:created) { Time.zone.now - 1.year }
      let!(:provider) { create(:provider, id: "bl", name: "British Library", created: created) }

      before do
        sleep 1
        get "/providers?year=#{created.year}", headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(1)
        expect(response).to have_http_status(200)
      end
    end

    context 'filter by two years' do
      let(:created) { Time.zone.now - 1.year }
      let(:years) { [created.year, created.year - 1].join(",") }
      let!(:provider) { create(:provider, id: "bl", name: "British Library", created: created) }
      let!(:alt_provider) { create(:provider, id: "sl", name: "Scottish Library", created: created - 1.year) }

      before do
        sleep 1
        get "/providers?year=#{years}", headers: headers
      end

      it 'returns providers' do
        expect(json['data'].size).to eq(2)
        expect(response).to have_http_status(200)
      end
    end
  end

  describe 'GET /providers/:id' do
    context 'when the record exists' do
      let(:provider) { create(:provider, id: "bl", name: "British Library") }

      before { get "/providers/#{provider.id}", headers: headers }

      it 'returns the provider' do
        expect(response).to have_http_status(200)
        expect(json.dig('data', 'id')).to eq(provider.id)
        expect(json.dig('data', 'attributes', 'name')).to eq(provider.name)
      end
    end

    context 'when the record exists upcase' do
      let(:provider) { create(:provider, id: "bl", name: "British Library") }

      before { get "/providers/#{provider.symbol}", headers: headers }

      it 'returns the provider' do
        expect(response).to have_http_status(200)
        expect(json.dig('data', 'id')).to eq(provider.id)
        expect(json.dig('data', 'attributes', 'name')).to eq(provider.name)
      end
    end

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
                        "contact-email" => "doe@joe.joe",
                        "contact-name" => "timAus",
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
                        "contact-name" => "timAus",
                        "created" =>"2017-08-29T06:54:15Z" ,
                        "country-code" => "GB" } } }
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

      it 'returns status code 400' do
        expect(response).to have_http_status(400)
      end

      it 'returns a validation failure message' do
        expect(json["errors"].first).to eq("status"=>"400", "title"=>"You need to provide a payload following the JSONAPI spec")
      end
    end

    context 'when the the resource exist already' do
      let(:provider) { create(:provider, id: "bl", name: "British Library") }

      before { post '/providers', params: provider.to_jsonapi.to_json, headers: headers }

      it 'returns status code 422' do
        expect(response).to have_http_status(422)
      end
    end
  end

  describe 'PUT /providers/:id' do
    context 'when the record exists' do
      let(:provider) { create(:provider, id: "bl", name: "British Library") }

      let(:params) do
        { "data" => { "type" => "providers",
                      "attributes" => {
                        "contact-email" => "bob@example.com",
                        "contact-name" => "Josiah Carberry",
                        "symbol" => provider.symbol,
                        "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
                        "name" => "British Library 2"}} }
      end

      before do
        put "/providers/#{provider.id}", params: params.to_json, headers: headers
      end

      it 'updates the record' do
        expect(json.dig('data', 'attributes', 'name')).to eq("British Library 2")
        expect(json.dig('data', 'attributes', 'contact-name')).to eq("Josiah Carberry")
        expect(response).to have_http_status(200)
      end
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

  describe 'DELETE /providers/:id' do
    context 'when the resources exist' do
      let(:provider) { create(:provider, id: "bl", name: "British Library") }

      before { delete "/providers/#{provider.id}", headers: headers }

      it 'returns status code 204' do
        expect(response).to have_http_status(204)
        expect(response.body).to be_blank
      end
    end

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
