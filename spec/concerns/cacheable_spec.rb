require "rails_helper"

describe "Cacheable", type: :concern do
  let(:token) { User.generate_token }
  subject { User.new(token) }

  describe "#cached_datacite_response" do
    before do
      Rails.cache.delete("datacite/100")
    end

    describe "when the is a cache miss" do
      it "will fetch the value using Base.get_datacite_metadata" do
        allow(Base).to(receive(:get_datacite_metadata).and_return({message: "from get_datacite_metadata"}))
        result = RelatedIdentifier.cached_datacite_response(100)
        expect(result).to(eq({message: "from get_datacite_metadata"}))
      end
    end

    describe "when there is a cache hit" do
      it "will fetch the value from cache" do
        Rails.cache.fetch("datacite/100", expires_in: 1.day) { { message: "from cache" } }
        allow(Base).to(receive(:get_datacite_metadata).and_return({message: "from get_datacite_metadata"}))
        result = RelatedIdentifier.cached_datacite_response(100)
        expect(result).to(eq({message: "from cache"}))
      end
    end
  end

  describe "#cached_doi_ra" do
    before do
      Rails.cache.delete("ras/100")
    end

    describe "when the is a cache miss" do
      it "will fetch the value using Base.get_doi_ra" do
        allow(Base).to(receive(:validate_prefix).and_return("http://doi.org/10.abcdefg"))
        allow(Base).to(receive(:get_doi_ra).with("http://doi.org/10.abcdefg").and_return("fake_prefix"))
        result = RelatedIdentifier.cached_doi_ra("100")
        expect(result).to(eq("fake_prefix"))
      end
    end

    describe "when there is a cache hit" do
      it "will fetch the value from cache" do
        Rails.cache.fetch("ras/100", expires_in: 1.day) { { message: "from cache" } }
        result = RelatedIdentifier.cached_doi_ra("100")
        expect(result).to(eq({message: "from cache"}))
      end
    end
  end
end
