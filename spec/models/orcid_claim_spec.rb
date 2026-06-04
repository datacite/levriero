require "rails_helper"

describe OrcidClaim, type: :model, vcr: true do
  describe "push_item" do
    it "sends a message to the events queue" do
      allow(ENV).to(receive(:[]).and_return("token"))
      allow(OrcidClaim).to(receive(:send_event_import_message).and_return(nil))
      allow(Rails.logger).to(receive(:info))

      item = {
        "updated" => Time.now.utc.to_s,
        "doi" => "10.5678/main",
        "subj-id" => "subj-id",
        "relation-type-id" => "relation-type-id",
        "obj-id" => "obj-id",
        "relatedIdentifiers" => [
          {
            "relatedIdentifierType" => "DOI",
            "relatedIdentifier" => "https://doi.org/10.5678/related",
            "relationType" => "is-identical-to",
          },
        ],
        "nameIdentifier" => "identifier_scheme:https://orcid.org/0000-0000-0000-0000",
      }

      OrcidClaim.push_item(item)

      expect(OrcidClaim).to(have_received(:send_event_import_message).once)
      expect(Rails.logger).to(have_received(:info).with("[Event Data] https://doi.org/10.5678/main is_authored_by https://orcid.org/0000-0000-0000-0000 sent to the events queue."))
    end
  end
end
