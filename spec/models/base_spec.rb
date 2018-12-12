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
    it "fetch metadata ScholarlyArticle" do
      id = "https://doi.org/10.5438/4k3m-nyvg"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.5438/4k3m-nyvg")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["name"]).to eq("Eating your own Dog Food")
      expect(response["author"].length).to eq(1)
      expect(response["author"].first).to eq("@type"=>"Person", "familyName"=>"Fenner", "givenName"=>"Martin", "name"=>"Martin Fenner")
      expect(response["publisher"]).to eq("@type"=>"Organization", "name"=>"DataCite")
      expect(response["registrantId"]).to eq("datacite.demo.datacite")
      expect(response["proxyIdentifiers"]).to be_empty
      expect(response["datePublished"]).to eq("2016-12-20")
      expect(response["dateModified"]).to eq("2018-08-01T22:04:55.000Z")
    end

    it "fetch metadata Dataset" do
      id = "https://doi.org/10.4124/ccvcn4z"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.4124/ccvcn4z")
      expect(response["@type"]).to eq("Dataset")
      expect(response["name"]).to eq("CCDC 785761: Experimental Crystal Structure Determination")
      expect(response["author"].length).to eq(5)
      expect(response["author"].first).to eq("@type"=>"Person", "familyName"=>"Phillips", "givenName"=>"A.E.", "name"=>"A.E. Phillips")
      expect(response["publisher"]).to eq("@type"=>"Organization", "name"=>"Cambridge Crystallographic Data Centre")
      expect(response["registrantId"]).to eq("datacite.bl.ccdc")
      expect(response["proxyIdentifiers"]).to eq(["10.1021/ja906895j"])
      expect(response["datePublished"]).to eq("2010")
      expect(response["dateModified"]).to eq("2018-02-05T09:53:27.000Z")
    end

    it "fetch metadata with funding information" do
      id = "https://doi.org/10.70048/m6at-x929"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.70048/m6at-x929")
      expect(response["@type"]).to eq("SoftwareSourceCode")
      expect(response["name"]).to eq("DataCite DOI Test Example")
      expect(response["author"].length).to eq(2)
      expect(response["author"].first).to eq("@id"=>"https://orcid.org/0000-0002-7352-517X", "@type"=>"Person", "familyName"=>"Hallett", "givenName"=>"Richard", "name"=>"Richard Hallett", "affiliation" => {"@type"=>"Organization", "name"=>"DataCite"})
      expect(response["publisher"]).to eq("@type"=>"Organization", "name"=>"DataCite")
      expect(response["funder"]).to eq("@id"=>"https://doi.org/10.13039/100000001", "@type"=>"Organization", "name"=>"National Science Foundation")
      expect(response["registrantId"]).to eq("datacite.datacite.rph")
      expect(response["proxyIdentifiers"]).to be_empty
      expect(response["datePublished"]).to eq("2017")
      expect(response["dateModified"]).to eq("2018-11-13T09:46:57.000Z")
    end

    it "fetch metadata with author information" do
      id = "https://doi.org/10.5438/0x88-gvge"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.5438/0x88-gvge")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["name"]).to eq("EZID DOI Service is Evolving")
      expect(response["author"].length).to eq(3)
      expect(response["author"].first).to eq("@id"=>"https://orcid.org/0000-0002-9300-5278", "@type"=>"Person", "familyName"=>"Cruse", "givenName"=>"Patricia", "name"=>"Patricia Cruse")
      expect(response["publisher"]).to eq("@type"=>"Organization", "name"=>"DataCite")
      expect(response["periodical"]).to eq("@id"=>"https://doi.org/10.5438/0000-00ss", "@type"=>"Periodical", "name"=>"DataCite Blog")
      expect(response["registrantId"]).to eq("datacite.datacite.datacite")
      expect(response["proxyIdentifiers"]).to eq(["10.5438/0000-00ss"])
      expect(response["datePublished"]).to eq("2017-08-04")
      expect(response["dateModified"]).to eq("2018-11-10T02:00:51.000Z")
    end
  end


  context "get_crossref_metadata" do
    it "fetch crossref metadata" do
      id = "https://doi.org/10.1055/s-0030-1259729"
      response = Base.get_crossref_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.1055/s-0030-1259729")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["name"]).to eq("Copper-Catalyzed Aromatic C-H Bond Halogenation Using Lithium Halides as Halogenating Reagents")
      expect(response["periodical"]).to eq("@type"=>"Periodical", "issn"=>"0936-5214", "name"=>"Synlett")
      expect(response["publisher"]).to eq("@type"=>"Organization", "name"=>"Georg Thieme Verlag KG")
      expect(response["registrantId"]).to eq("crossref.194")
      expect(response["datePublished"]).to eq("2011-03-10")
      expect(response["dateModified"]).to eq("2018-11-27T15:42:54Z")
    end
  end

  context "get_orcid_metadata" do
    it "fetch orcid metadata" do
      id = "https://orcid.org/0000-0003-1419-2405"
      response = Base.get_orcid_metadata(id)
      expect(response["@id"]).to eq("https://orcid.org/0000-0003-1419-2405")
      expect(response["@type"]).to eq("Person")
      expect(response["givenName"]).to eq("Martin")
      expect(response["familyName"]).to eq("Fenner")
      expect(response["name"]).to eq("Martin Fenner")
    end
  end
end