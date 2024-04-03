require "rails_helper"

describe "Cacheable", type: :concern do
  let(:token) { User.generate_token }
  subject { User.new(token) }

  describe "cached_datacite_response" do
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
        allow(Rails).to(receive_message_chain(:cache, :fetch).and_return({message: "from cache"}))
        allow(Base).to(receive(:get_datacite_metadata).and_return({message: "from get_datacite_metadata"}))

        result = RelatedIdentifier.cached_datacite_response(100)
        expect(result).to(eq({message: "from cache"}))
      end
    end
  end
end
