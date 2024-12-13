namespace :event_import_worker do
  desc "Import for a single doi"
  task import_doi: :environment do
    data = {id: "10.82608/4ds0-vv20"}.to_json
    response = Doi.parse_record(sqs_msg: nil, data: JSON.parse(data))
    puts response
  end

  desc "Process a message"
  task process_message: :environment do
    RelatedUrl.receive_event_message
  end
end
