require "rails_helper"

describe "Importable", vcr: true do
  # context "Doi" do
  #   describe "import_from_api" do
  #     # return number of clients or providers imported into Elasticsearch
  #     it "import" do
  #       expect(Client.import_from_api).to eq(1440)
  #     end
  #   end

  #   describe "import_record" do
  #     let(:client) { create(:client) }
  #     let(:data_for_client) { { "id" => client.attributes[:symbol].downcase, "type" => "clients", "attributes" => client.attributes.except(:id, :created_at, :updated_at) } }
  #     let(:attributes) { attributes_for(:client) }
  #     let(:data) { { "id" => attributes["id"], "type" => "clients", "attributes" => attributes } }

  #     it "create" do
  #       client = Client.import_record(data)
  #       expect(client).to be_valid
  #     end

  #     it "update" do
  #       client = Client.import_record(data_for_client)
  #       expect(client).to be_valid
  #     end

  #     it "update invalid" do
  #       data_for_client["attributes"][:contact_email] = nil
  #       client = Client.import_record(data_for_client)
  #       expect(client).not_to be_valid
  #       expect(client.errors.to_a).to eq(["Contact email can't be blank"])
  #     end
  #   end

  #   describe "create_record" do
  #     let(:attributes) { attributes_for(:client) }

  #     it "valid" do
  #       client = Client.create_record(attributes)
  #       expect(client).to be_valid
  #     end

  #     it "missing attribute" do
  #       client = Client.create_record(attributes.except(:contact_email))
  #       expect(client).not_to be_valid
  #       expect(client.errors.to_a).to eq(["Contact email can't be blank"])
  #     end
  #   end

  #   describe "update_record" do
  #     let(:client) { create(:client) }

  #     it "valid" do
  #       attributes = { "contact_email" => "info@example.org" }
  #       client.update_record(attributes)
  #       expect(client).to be_valid
  #       expect(client.contact_email).to eq("info@example.org")
  #     end

  #     it "missing attribute" do
  #       attributes = { "contact_email" => nil }
  #       client.update_record(attributes)
  #       expect(client).not_to be_valid
  #       expect(client.errors.to_a).to eq(["Contact email can't be blank"])
  #     end
  #   end

  #   describe "delete_record" do
  #     let(:client) { create(:client) }

  #     it "valid" do
  #       client.delete_record
  #       expect(client.destroyed?).to be true
  #     end
  #   end
  # end

  describe "to_kebab_case" do
    it "converts" do
      hsh = { "provider-id" => "bl", "country-code" => "GB" }
      expect(Doi.to_kebab_case(hsh)).to eq("provider_id" => "bl",
                                           "country_code" => "GB")
    end
  end

  context "normalize doi" do
    it "doi" do
      doi = "10.5061/DRYAD.8515"
      response = Doi.normalize_doi(doi)
      expect(response).to eq("https://doi.org/10.5061/dryad.8515")
    end

    it "doi with protocol" do
      doi = "doi:10.5061/DRYAD.8515"
      response = Doi.normalize_doi(doi)
      expect(response).to eq("https://doi.org/10.5061/dryad.8515")
    end

    it "SICI doi" do
      doi = "10.1890/0012-9658(2006)87[2832:tiopma]2.0.co;2"
      response = Doi.normalize_doi(doi)
      expect(response).to eq("https://doi.org/10.1890/0012-9658(2006)87%5B2832:tiopma%5D2.0.co;2")
    end

    it "https url" do
      doi = "https://doi.org/10.5061/dryad.8515"
      response = Doi.normalize_doi(doi)
      expect(response).to eq("https://doi.org/10.5061/dryad.8515")
    end

    it "dx.doi.org url" do
      doi = "http://dx.doi.org/10.5061/dryad.8515"
      response = Doi.normalize_doi(doi)
      expect(response).to eq("https://doi.org/10.5061/dryad.8515")
    end

    it "not valid doi prefix" do
      doi = "https://doi.org/20.5061/dryad.8515"
      response = Doi.normalize_doi(doi)
      expect(response).to be_nil
    end

    it "doi prefix with string" do
      doi = "https://doi.org/10.506X/dryad.8515"
      response = Doi.normalize_doi(doi)
      expect(response).to be_nil
    end

    it "doi prefix too long" do
      doi = "https://doi.org/10.506123/dryad.8515"
      response = Doi.normalize_doi(doi)
      expect(response).to be_nil
    end

    it "doi from url without doi proxy" do
      doi = "https://handle.net/10.5061/dryad.8515"
      response = Doi.normalize_doi(doi)
      expect(response).to be_nil
    end
  end

  describe "normalize_url" do
    it "normalizes" do
      url = "https://example.com/abc?utm_source=FeedBurner#stuff"
      expect(Doi.normalize_url(url)).to eq("https://example.com/abc")
    end

    it "ftp url" do
      url = "ftp://example.com/abc"
      expect(Doi.normalize_url(url)).to eq(url)
    end

    it "s3 url" do
      url = "s3://example.com/abc"
      expect(Doi.normalize_url(url)).to eq(url)
    end

    it "mailto url" do
      url = "mailto:info@example.com"
      expect(Doi.normalize_url(url)).to be_nil
    end
  end

  describe "normalize_arxiv" do
    it "url" do
      arxiv = "https://arxiv.org/abs/1510.08458"
      expect(Doi.normalize_arxiv(arxiv)).to eq("https://arxiv.org/abs/1510.08458")
    end

    it "arXiv" do
      arxiv = "arXiv:0706.0001"
      expect(Doi.normalize_arxiv(arxiv)).to eq("https://arxiv.org/abs/0706.0001")
    end

    it "arxiv" do
      arxiv = "arxiv:0706.0001"
      expect(Doi.normalize_arxiv(arxiv)).to eq("https://arxiv.org/abs/0706.0001")
    end
  end

  describe "normalize_igsn" do
    it "handle.net url" do
      igsn = "https://hdl.handle.net/10723/EDYSAN001"
      expect(Doi.normalize_igsn(igsn)).to eq("https://hdl.handle.net/10723/edysan001")
    end

    it "igsn url" do
      igsn = "http://igsn.org/EDYSAN001"
      expect(Doi.normalize_igsn(igsn)).to eq("https://hdl.handle.net/10273/edysan001")
    end

    it "igsn" do
      igsn = "EDYSAN001"
      expect(Doi.normalize_igsn(igsn)).to eq("https://hdl.handle.net/10273/edysan001")
    end
  end

  describe "normalize_handle" do
    it "handle.net url" do
      handle = "https://hdl.handle.net/10013/epic.45340.d001"
      expect(Doi.normalize_handle(handle)).to eq("https://hdl.handle.net/10013/epic.45340.d001")
    end

    it "handle" do
      handle = "10013/epic.45340.d001"
      expect(Doi.normalize_handle(handle)).to eq("https://hdl.handle.net/10013/epic.45340.d001")
    end
  end

  describe "normalize_pmid" do
    it "identifiers.org url" do
      pmid = "https://identifiers.org/pubmed:19956380"
      expect(Doi.normalize_pmid(pmid)).to eq("https://identifiers.org/pubmed:19956380")
    end

    it "pmid with prefix" do
      pmid = "pmid:19956380"
      expect(Doi.normalize_pmid(pmid)).to eq("https://identifiers.org/pubmed:19956380")
    end

    it "pmid" do
      pmid = "19956380"
      expect(Doi.normalize_pmid(pmid)).to eq("https://identifiers.org/pubmed:19956380")
    end
  end

  describe "normalize_orcid" do
    it "https url" do
      orcid = "https://orcid.org/0000-0003-1419-2405"
      expect(Doi.normalize_orcid(orcid)).to eq(orcid)
    end

    it "http url" do
      orcid = "http://orcid.org/0000-0003-1419-2405"
      expect(Doi.normalize_orcid(orcid)).to eq("https://orcid.org/0000-0003-1419-2405")
    end

    it "as string" do
      orcid = "0000-0003-1419-2405"
      expect(Doi.normalize_orcid(orcid)).to eq("https://orcid.org/0000-0003-1419-2405")
    end

    it "no hyphens" do
      orcid = "https://orcid.org/0000 0003 1419 2405"
      expect(Doi.normalize_orcid(orcid)).to eq("https://orcid.org/0000-0003-1419-2405")
    end
  end

  describe "normalize_ror" do
    it "https url" do
      ror_id = "https://ror.org/02catss52"
      expect(Doi.normalize_ror(ror_id)).to eq(ror_id)
    end

    it "http url" do
      ror_id = "http://ror.org/02catss52"
      expect(Doi.normalize_ror(ror_id)).to eq("https://ror.org/02catss52")
    end

    it "as string" do
      ror_id = "ror.org/02catss52"
      expect(Doi.normalize_ror(ror_id)).to eq("https://ror.org/02catss52")
    end
  end

  describe "get_doi_ra" do
    it "DataCite" do
      prefix = "10.5061"
      expect(Doi.get_doi_ra(prefix)).to eq("DataCite")
    end

    it "Crossref" do
      prefix = "10.1371"
      expect(Doi.get_doi_ra(prefix)).to eq("Crossref")
    end

    it "unknown prefix" do
      prefix = "10.9999"
      expect(Doi.get_doi_ra(prefix)).to be_nil
    end
  end

  describe "parse_record" do
    let!(:data) { { "id" => "fake_id" } }

    describe "has related identifiers" do
      describe "with related identifier type 'DOI'" do
        it "sends push_item to RelatedIdentifier" do
          json = {
            "relatedIdentifiers" => [
              { "relatedIdentifierType" => "DOI" },
              { "relatedIdentifierType" => "FOO" },
            ],
          }

          allow(RelatedIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(RelatedIdentifier).
            to(have_received(:push_item).with({
                                                "id" => "fake_id",
                                                "type" => "dois",
                                                "attributes" => json,
                                              }).once)
        end
      end

      describe "without related identifier type 'DOI'" do
        it "does not send push_item to RelatedIdentifier" do
          json = {
            "relatedIdentifiers" => [
              { "relatedIdentifierType" => "URL" },
              { "relatedIdentifierType" => "FOO" },
            ],
          }

          allow(RelatedIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(RelatedIdentifier).not_to(have_received(:push_item))
        end
      end

      describe "with related identifier type 'URL'" do
        it "sends push_item to RelatedIdentifier" do
          json = {
            "relatedIdentifiers" => [
              { "relatedIdentifierType" => "URL" },
              { "relatedIdentifierType" => "FOO" },
            ],
          }

          allow(RelatedUrl).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(RelatedUrl).
            to(have_received(:push_item).with({
                                                "id" => "fake_id",
                                                "type" => "dois",
                                                "attributes" => json,
                                              }).once)
        end
      end

      describe "without related identifier type 'URL'" do
        it "does not send push_item to RelatedIdentifier" do
          json = {
            relatedIdentifiers: [
              { "relatedIdentifierType" => "DOI" },
              { "relatedIdentifierType" => "FOO" },
            ],
          }

          allow(RelatedUrl).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(RelatedUrl).not_to(have_received(:push_item))
        end
      end
    end

    describe "has funding references" do
      describe "with funding identifier type 'Crossref Funder ID" do
        it "sends push_item to FunderIdentifier" do
          json = {
            "fundingReferences" => [
              { "funderIdentifierType" => "Foo" },
              { "funderIdentifierType" => "Crossref Funder ID" },
            ],
          }

          allow(FunderIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(FunderIdentifier).
            to(have_received(:push_item).with({
                                                "doi" => "fake_id",
                                                "type" => "dois",
                                                "attributes" => json,
                                              }).once)
        end
      end

      describe "without funding identifier type 'Crossref Funder ID" do
        it "does not send push_item to FunderIdentifier" do
          json = {
            "fundingReferences" => [
              { "funderIdentifierType" => "Foo" },
              { "funderIdentifierType" => "Bar" },
            ],
          }

          allow(FunderIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(FunderIdentifier).not_to(have_received(:push_item))
        end
      end
    end

    describe "has name identifiers" do
      describe "with name identifier scheme equal to 'ORCID'" do
        it "sends push_item to NameIdentifier" do
          json = {
            "creators" => [
              {
                "nameIdentifiers" => [
                  { "nameIdentifierScheme" => "ORCID" },
                  { "nameIdentifierScheme" => "FOO" },
                ],
              },
            ],
          }

          allow(NameIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(NameIdentifier).
            to(have_received(:push_item).with({
                                                "doi" => "fake_id",
                                                "type" => "dois",
                                                "attributes" => json,
                                              }).once)
        end
      end

      describe "without name identifier scheme equal to 'ORCID'" do
        it "does not send push_item to NameIdentifier" do
          json = {
            "creators" => [
              {
                "nameIdentifiers" => [
                  { "nameIdentifierScheme" => "FOO" },
                  { "nameIdentifierScheme" => "BAR" },
                ],
              },
            ],
          }

          allow(NameIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(NameIdentifier).not_to(have_received(:push_item))
        end
      end
    end

    describe "has affliation identifiers" do
      describe "with affiliation identifier scheme equal to 'ROR' and name identifier scheme equal to 'ORCID'" do
        it "sends push_item to AffiliationIdentifier" do
          json = {
            "creators" => [
              {
                "affiliation" => [
                  { "affiliationIdentifierScheme" => "ROR" },
                ],
                "nameIdentifiers" => [
                  { "nameIdentifierScheme" => "ORCID" },
                ],
              },
            ],
          }

          allow(AffiliationIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(AffiliationIdentifier).
            to(have_received(:push_item).with({
                                                "doi" => "fake_id",
                                                "type" => "dois",
                                                "attributes" => json,
                                              }).once)
        end
      end

      describe "with affiliation identifier scheme equal to 'ROR' and name identifier scheme not equal to 'ORCID'" do
        it "does not send push_item to AffiliationIdentifier" do
          json = {
            "creators" => [
              {
                "affiliation" => [
                  { "affiliationIdentifierScheme" => "ROR" },
                ],
                "nameIdentifiers" => [
                  { "nameIdentifierScheme" => "FOO" },
                ],
              },
            ],
          }

          allow(AffiliationIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(AffiliationIdentifier).not_to(have_received(:push_item))
        end
      end

      describe "with affiliation identifier scheme not equal to 'ROR' and name identifier scheme equal to 'ORCID'" do
        it "does not send push_item to AffiliationIdentifier" do
          json = {
            "creators" => [
              {
                "affiliation" => [
                  { "affiliationIdentifierScheme" => "FOO" },
                ],
                "nameIdentifiers" => [
                  { "nameIdentifierScheme" => "ORCID" },
                ],
              },
            ],
          }

          allow(AffiliationIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(AffiliationIdentifier).not_to(have_received(:push_item))
        end
      end

      describe "with affiliation identifier scheme not equal to 'ROR' and name identifier scheme not equal to 'ORCID'" do
        it "does not send push_item to AffiliationIdentifier" do
          json = {
            "creators" => [
              {
                "affiliation" => [
                  { "affiliationIdentifierScheme" => "FOO" },
                ],
                "nameIdentifiers" => [
                  { "nameIdentifierScheme" => "BAR" },
                ],
              },
            ],
          }

          allow(AffiliationIdentifier).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(AffiliationIdentifier).not_to(have_received(:push_item))
        end
      end
    end

    describe "has orcid affiliations" do
      describe "with affiliation identifier scheme equal to 'ROR'" do
        it "sends push_item to OrcidAffiliation" do
          json = {
            "creators" => [
              {
                "affiliation" => [
                  { "affiliationIdentifierScheme" => "ROR" },
                ],
              },
            ],
          }

          allow(OrcidAffiliation).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(OrcidAffiliation).
            to(have_received(:push_item).with({
                                                "doi" => "fake_id",
                                                "type" => "dois",
                                                "attributes" => json,
                                              }).once)
        end
      end

      describe "with affiliation identifier scheme not equal to 'ROR'" do
        it "does not send push_item to OrcidAffiliation" do
          json = {
            "creators" => [
              {
                "affiliation" => [
                  { "affiliationIdentifierScheme" => "ORCID" },
                ],
              },
            ],
          }

          allow(OrcidAffiliation).to(receive(:push_item))
          allow(Base).to(receive(:get_datacite_json).and_return(json))

          Base.parse_record(data: data)

          expect(OrcidAffiliation).not_to(have_received(:push_item))
        end
      end
    end
  end
end
