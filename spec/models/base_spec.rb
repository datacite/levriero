require 'rails_helper'

describe Base, type: :model, vcr: true do
  context "get_datacite_xml" do
    it "fetch metadata scholarly-article" do
      id = "https://doi.org/10.5438/4k3m-nyvgx"
      response = Base.get_datacite_xml(id)
      expect(response.dig("relatedIdentifiers", "relatedIdentifier").length).to eq(3)
      expect(response.dig("relatedIdentifiers", "relatedIdentifier").last).to eq("__content__"=>"10.5438/55e5-t5c0", "relatedIdentifierType"=>"DOI", "relationType"=>"References")
    end

    it "fetch metadata dataset" do
      id = "https://doi.org/10.4124/ccvcn4z"
      response = Base.get_datacite_xml(id)
      expect(response.dig("relatedIdentifiers", "relatedIdentifier")).to eq("__content__"=>"10.1021/ja906895j", "relatedIdentifierType"=>"DOI", "relationType"=>"IsSupplementTo")
    end
  end

  context "get_datacite_metadata" do
    it "fetch metadata scholarly-article" do
      id = "https://doi.org/10.5438/4k3m-nyvg"
      response = Base.get_datacite_metadata(id)
      expect(response["id"]).to eq("https://doi.org/10.5438/4k3m-nyvg")
      expect(response["type"]).to eq("scholarly-article")
      expect(response["name"]).to eq("Eating your own Dog Food")
      expect(response["publisher"]).to eq("DataCite")
      expect(response["provider_id"]).to eq("datacite.demo.datacite")
      expect(response["date_published"]).to eq("2016-12-20")
      expect(response["date_modified"]).to eq("2018-08-01T22:04:55.000Z")
    end

    it "fetch metadata dataset" do
      id = "https://doi.org/10.4124/ccvcn4z"
      response = Base.get_datacite_metadata(id)
      expect(response["id"]).to eq("https://doi.org/10.4124/ccvcn4z")
      expect(response["type"]).to eq("dataset")
      expect(response["name"]).to eq("CCDC 785761: Experimental Crystal Structure Determination")
      expect(response["publisher"]).to eq("Cambridge Crystallographic Data Centre")
      expect(response["provider_id"]).to eq("datacite.bl.ccdc")
      expect(response["date_published"]).to eq("2010")
      expect(response["date_modified"]).to eq("2018-02-05T09:53:27.000Z")
    end
  end

  context "get_crossref_metadata" do
    it "fetch crossref metadata" do
      id = "https://doi.org/10.1055/s-0030-1259729"
      response = Base.get_crossref_metadata(id)
      expect(response["id"]).to eq("https://doi.org/10.1055/s-0030-1259729")
      expect(response["type"]).to eq("scholarly-article")
      expect(response["name"]).to eq("Copper-Catalyzed Aromatic C-H Bond Halogenation Using Lithium Halides as Halogenating Reagents")
      expect(response["periodical"]).to eq("Synlett")
      expect(response["issn"]).to eq(["0936-5214", "1437-2096"])
      expect(response["publisher"]).to eq("Georg Thieme Verlag KG")
      expect(response["provider_id"]).to eq("crossref.194")
      expect(response["date_published"]).to eq("2011-03-10")
      expect(response["date_modified"]).to eq("2018-05-04T00:15:33Z")
    end
  end
end