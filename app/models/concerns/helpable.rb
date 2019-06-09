module Helpable
  extend ActiveSupport::Concern

  module ClassMethods
    def set_event_for_bus(event)
      event["source_id"] = "datacite"
      event["subj"] = format_for_bus(event["subj"])
      event["obj"] = format_for_bus(event["obj"])
      event
    end
  
    def format_for_bus(metadata)
      { "pid" => metadata["@id"],
        "work_type_id" => metadata["@type"] }.compact
    end
  
  end
end