require 'rails_helper'

describe RelatedIdentifier, type: :model do

  it "format event for eventdata bus" do
    event = File.read(fixture_path + 'datacite_event.json')
    response = RelatedIdentifier.set_event_for_bus JSON.parse(event), "25cb77e5-75fd-4bd2-9025-3d73654650fa"
    expect(response["id"]).not_to eq("")
    expect(response["source_id"]).to eq("datacite")
    expect(response["subj_id"]).to eq("https://doi.org/10.15468/dl.hy9tqg")
    expect(response["relation_type_id"]).to eq("references")
    expect(response["source_token"]).to eq("29a9a478-518f-4cbd-a133-a0dcef63d547")
    expect(response["obj"]).to eq({"pid"=>"https://doi.org/10.15468/xgoxap", "type"=>"Dataset"})
    expect(response["subj"]).to eq({"pid"=>"https://doi.org/10.15468/dl.hy9tqg", "type"=>"Dataset"})
  end
end


