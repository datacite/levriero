require 'rails_helper'

describe Base, type: :model, vcr: true do
  context "get_datacite_xml" do
    it "fetch metadata scholarly-article" do
      id = "https://doi.org/10.5438/mk65-3m12"
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

  context "get_datacite_json" do
    it "fetch metadata scholarly-article" do
      id = "https://doi.org/10.5438/mk65-3m12"
      response = Base.get_datacite_json(id)
      expect(response.fetch("relatedIdentifiers", []).length).to eq(3)
      expect(response.fetch("relatedIdentifiers", []).last).to eq("relatedIdentifier"=>"10.5438/55e5-t5c0", "relatedIdentifierType"=>"DOI", "relationType"=>"References")
    end

    it "fetch metadata dataset" do
      id = "https://doi.org/10.4124/ccvcn4z"
      response = Base.get_datacite_json(id)
      expect(response.fetch("relatedIdentifiers", [])).to eq([{"relatedIdentifier"=>"10.1021/ja906895j", "relatedIdentifierType"=>"DOI", "relationType"=>"IsSupplementTo"}])
    end
  end

  context "get_datacite_metadata" do
    it "fetch metadata ScholarlyArticle" do
      id = "https://doi.org/10.5438/mk65-3m12"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.5438/mk65-3m12")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["name"]).to eq("Eating your own Dog Food")
      expect(response["author"].length).to eq(1)
      expect(response["author"].first).to eq("@id"=>"https://orcid.org/0000-0003-1419-2405", "@type"=>"Person", "familyName"=>"Fenner", "givenName"=>"Martin", "name"=>"Martin Fenner")
      expect(response["publisher"]).to eq("@type"=>"Organization", "name"=>"DataCite")
      expect(response["registrantId"]).to eq("datacite.datacite.datacite")
      expect(response["proxyIdentifiers"]).to eq(["10.5438/0000-00ss"])
      expect(response["datePublished"]).to eq("2016-12-20")
      expect(Time.parse(response["dateModified"]).utc.iso8601).to eq("2019-06-05T09:31:21Z")
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
      expect(Time.parse(response["dateModified"]).utc.iso8601).to eq("2018-02-05T09:53:27Z")
    end

    it "fetch metadata with funding information" do
      id = "https://doi.org/10.21953/lse.6pv8ey9vxc10"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.21953/lse.6pv8ey9vxc10")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["name"]).to eq("Politics of sexuality in neoliberal(ized) times and\n spaces: LGBT movements and reparative therapy in\n contemporary Poland")
      expect(response["author"].length).to eq(1)
      expect(response["author"].first).to eq("@type"=>"Person", "affiliation" => {"@type"=>"Organization", "name"=>"London School of Economics and Political Science (LSE)"},
        "familyName" => "Mikulak",
        "givenName" => "Magdalena",
        "name" => "Magdalena Mikulak")
      expect(response["publisher"]).to eq("@type"=>"Organization", "name"=>"London School of Economics and Political Science (LSE)")
      expect(response["funder"]).to eq("@id"=>"https://doi.org/10.13039/100011326", "@type"=>"Organization", "name"=>"London School of Economics and Political Science (LSE)")
      expect(response["registrantId"]).to eq("datacite.bl.lse")
      expect(response["proxyIdentifiers"]).to eq(["http://etheses.lse.ac.uk/view/sets/LSE-GI.html"])
      expect(response["datePublished"]).to eq("2017")
      expect(Time.parse(response["dateModified"]).utc.iso8601).to eq("2018-01-10T12:47:33Z")
    end

    it "fetch metadata with author information" do
      id = "https://doi.org/10.17863/cam.10441"
      response = Base.get_datacite_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.17863/cam.10441")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["name"]).to eq("Comparison of ventricular drain location and infusion test in hydrocephalus")
      expect(response["author"].length).to eq(10)
      expect(response["author"].first).to eq("@id"=>"https://orcid.org/0000-0001-6459-4141", "@type"=>"Person", "familyName"=>"Sinha", "givenName"=>"Rohitashwa", "name"=>"Rohitashwa Sinha")
      expect(response["publisher"]).to eq("@type"=>"Organization", "name"=>"Apollo - University of Cambridge Repository (staging)")
      expect(response["registrantId"]).to eq("datacite.bl.cam")
      expect(response["datePublished"]).to eq("2017-03")
      expect(Time.parse(response["dateModified"]).utc.iso8601).to eq("2019-01-26T07:45:13Z")
    end
  end

  context "get_crossref_metadata" do
    it "fetch crossref metadata" do
      id = "https://doi.org/10.1055/s-0030-1259729"
      response = Base.get_crossref_metadata(id)
      expect(response["@id"]).to eq("https://doi.org/10.1055/s-0030-1259729")
      expect(response["@type"]).to eq("ScholarlyArticle")
      expect(response["name"]).to eq("Copper-Catalyzed Aromatic C-H Bond Halogenation Using Lithium Halides as Halogenating Reagents")
      expect(response["periodical"]).to eq("@id"=>"0936-5214", "@type"=>"Periodical", "name"=>"Synlett")
      expect(response["publisher"]).to eq("@type"=>"Organization", "name"=>"(:unav)")
      expect(response["registrantId"]).to eq("datacite.crossref.citations")
      expect(response["datePublished"]).to eq("2011-03-10")
      expect(Time.parse(response["dateModified"]).utc.iso8601).to eq("2019-06-09T16:45:26Z")
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