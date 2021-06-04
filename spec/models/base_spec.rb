require "rails_helper"

describe Base, type: :model, vcr: true do
  context "get_datacite_xml" do
    it "fetch metadata scholarly-article" do
      id = "https://doi.org/10.5438/mk65-3m12"
      response = Base.get_datacite_xml(id)
      expect(response.dig("relatedIdentifiers",
                          "relatedIdentifier").length).to eq(3)
      expect(response.dig("relatedIdentifiers",
                          "relatedIdentifier").last).to eq("__content__" => "10.5438/55e5-t5c0",
                                                           "relatedIdentifierType" => "DOI", "relationType" => "References")
    end

    it "fetch metadata dataset" do
      id = "https://doi.org/10.4124/ccvcn4z"
      response = Base.get_datacite_xml(id)
      expect(response.dig("relatedIdentifiers",
                          "relatedIdentifier")).to eq("__content__" => "10.1021/ja906895j",
                                                      "relatedIdentifierType" => "DOI", "relationType" => "IsSupplementTo")
    end
  end

  context "get_datacite_json" do
    it "fetch metadata scholarly-article" do
      id = "https://doi.org/10.5438/mk65-3m12"
      response = Base.get_datacite_json(id)
      expect(response.fetch("relatedIdentifiers", []).length).to eq(3)
      expect(response.fetch("relatedIdentifiers",
                            []).last).to eq("relatedIdentifier" => "10.5438/55e5-t5c0",
                                            "relatedIdentifierType" => "DOI", "relationType" => "References")
    end

    it "fetch metadata dataset" do
      id = "https://doi.org/10.4124/ccvcn4z"
      response = Base.get_datacite_json(id)
      expect(response.fetch("relatedIdentifiers",
                            [])).to eq([{ "relatedIdentifier" => "10.1021/ja906895j",
                                          "relatedIdentifierType" => "DOI", "relationType" => "IsSupplementTo" }])
    end
  end

  context "get_datacite_metadata" do
    it "fetch metadata ScholarlyArticle" do
      id = "https://doi.org/10.5438/mk65-3m12"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.5438/mk65-3m12")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["registrantId"]).to eq("datacite.datacite.datacite")
      expect(response["proxyIdentifiers"]).to eq(["10.5438/0000-00ss"])
      expect(response["datePublished"]).to eq("2016-12-20")
    end

    it "fetch metadata Dataset" do
      id = "https://doi.org/10.4124/ccvcn4z"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.4124/ccvcn4z")
      expect(response["@type"]).to eq("Dataset")
      expect(response["registrantId"]).to eq("datacite.ccdc.ccdc")
      expect(response["proxyIdentifiers"]).to eq(["10.1021/ja906895j"])
      expect(response["datePublished"]).to eq("2010")
    end

    it "fetch metadata with funding information" do
      id = "https://doi.org/10.70112/d7svvt"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.70112/d7svvt")
      expect(response["@type"]).to eq("Dataset")
      expect(response["registrantId"]).to eq("datacite.inist.inra")
      expect(response["proxyIdentifiers"]).to be_empty
      expect(response["datePublished"]).to eq("2018")
    end

    it "fetch metadata with author information" do
      id = "https://doi.org/10.17863/cam.10441"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.17863/cam.10441")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["registrantId"]).to eq("datacite.bl.cam")
      expect(response["datePublished"]).to eq("2017-03")
    end
  end

  context "get_crossref_metadata" do
    it "fetch crossref metadata" do
      id = "https://doi.org/10.1055/s-0030-1259729"
      response = Base.get_crossref_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.1055/s-0030-1259729")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["registrantId"]).to eq("crossref.194")
      expect(response["datePublished"]).to eq("2011-03-10")
    end
  end

  context "get_crossref_member_id" do
    it "fetch crossref member_id" do
      id = "10.1055/s-0030-1259729"
      options = {}
      response = Base.get_crossref_member_id(id, options)
      expect(response).to eq("crossref.194")
    end
  end

  context "get_orcid_metadata" do
    it "fetch orcid metadata" do
      id = "https://orcid.org/0000-0002-2203-2076"
      response = Base.get_orcid_metadata(id)
      expect(response["@id"]).to eq("https://orcid.org/0000-0002-2203-2076")
      expect(response["@type"]).to eq("Person")
    end
  end
end
