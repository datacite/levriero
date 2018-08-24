require 'rails_helper'

describe Base, type: :model, vcr: true do
  context "get_datacite_metadata" do
    it "fetch metadata scholarly-article" do
      id = "https://doi.org/10.5438/4k3m-nyvg"
      response = Base.get_datacite_metadata(id)
      expect(response["id"]).to eq("https://doi.org/10.5438/4k3m-nyvg")
      expect(response["type"]).to eq("scholarly-article")
      expect(response["name"]).to eq("Eating your own Dog Food")
      expect(response["publisher"]).to eq("DataCite")
      expect(response["provider-id"]).to eq("datacite.datacite.datacite")
    end

    it "fetch metadata dataset" do
      id = "https://doi.org/10.5061/dryad.8515"
      response = Base.get_datacite_metadata(id)
      expect(response["id"]).to eq("https://doi.org/10.5061/dryad.8515")
      expect(response["type"]).to eq("dataset")
      expect(response["name"]).to eq("Data from: A new malaria agent in African hominids.")
      expect(response["publisher"]).to eq("Dryad Digital Repository")
      expect(response["provider-id"]).to eq("datacite.dryad.dryad")
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
      expect(response["provider-id"]).to eq("crossref.194")
    end
  end
end