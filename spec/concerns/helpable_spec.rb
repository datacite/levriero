require 'rails_helper'

describe RelatedIdentifier, type: :model do

  it "format event for eventdata bus" do
    event = File.read(fixture_path + 'datacite_event.json')
    response = RelatedIdentifier.set_event_for_bus JSON.parse(event)
    expect(response["id"]).not_to eq(nil)
    expect(response["source_id"]).to eq("datacite")
    expect(response["subj_id"]).to eq("https://doi.org/10.15468/dl.hy9tqg")
    expect(response["relation_type_id"]).to eq("references")
    expect(response["source_token"]).to eq("29a9a478-518f-4cbd-a133-a0dcef63d547")
    expect(response["obj"]).to eq({"pid"=>"https://doi.org/10.15468/xgoxap", "work_type_id"=>"Dataset"})
    expect(response["subj"]).to eq({"pid"=>"https://doi.org/10.15468/dl.hy9tqg", "work_type_id"=>"Dataset"})
  end
end


