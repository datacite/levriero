require 'rails_helper'

describe 'Clients', type: :request, elasticsearch: true, vcr: true do
  let(:params) do
    { "data" => { "type" => "clients",
                  "attributes" => {
                    "symbol" => "BL.IMPERIAL",
                    "name" => "Imperial College",
                    "contact-name" => "Madonna",
                    "created" => Faker::Time.between(DateTime.now - 2, DateTime.now) ,
                    "contact-email" => "bob@example.com" },
                    "relationships" => {
                			"provider" => {
                				"data" => {
                					"type" => "clients",
                					"id" => "ABC"
                				}
                			}
                		}} }
  end
  let(:headers) { {'ACCEPT'=>'application/vnd.api+json', 'CONTENT_TYPE'=>'application/vnd.api+json', 'Authorization' => 'Bearer ' + User.generate_token}}

  describe 'GET /clients' do
    let!(:clients) { create_list(:client, 3) }

    context 'sort by created' do
      before do
        sleep 1
        get '/clients?sort=created', headers: headers
      end

      it 'returns clients' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'sort by created desc' do
      before do
        sleep 1
        get '/clients?sort=-created', headers: headers
      end

      it 'returns clients' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'sort by name' do
      before do
        sleep 1
        get '/clients?sort=name', headers: headers
      end

      it 'returns clients' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'sort by name desc' do
      before do
        sleep 1
        get '/clients?sort=-name', headers: headers
      end

      it 'returns clients' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'sort default' do
      before do
        sleep 1
        get '/clients', headers: headers
      end

      it 'returns clients' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'page[size]=2' do
      before do
        sleep 1
        get '/clients?page[size]=2', headers: headers
      end

      it 'returns clients' do
        expect(json['data'].size).to eq(2)
        expect(response).to have_http_status(200)
      end
    end

    context 'page[size]=100' do
      before do
        sleep 1
        get '/clients?page[size]=100', headers: headers
      end

      it 'returns clients' do
        expect(json['data'].size).to eq(3)
        expect(response).to have_http_status(200)
      end
    end

    context 'page[size]=2 and page[number]=2' do
      before do
        sleep 1
        get '/clients?page[size]=2&page[number]=2', headers: headers
      end

      it 'returns clients' do
        expect(json['data'].size).to eq(1)
        expect(response).to have_http_status(200)
      end
    end
  end

  describe 'GET /clients/:id' do
    context 'when the record exists' do
      let(:client) { create(:client, id: "bl.imperial", name: "Imperial College") }

      before { get "/clients/#{client.id}", headers: headers }

      it 'returns the client' do
        expect(response).to have_http_status(200)
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
