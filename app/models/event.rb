class Event < Base
  def process_message(sqs_msg, data)
    if data.blank?
      Rails.logger.info("[Event Import] data object is blank.")
      return
    end

    response = post_to_event_service(data.to_json)
    handle_logging(response, log_prefix)
  end

  private

  def post_to_event_service
    Maremma.post(
      "#{ENV['LAGOTTINO_URL']}/events",
      data: data.to_json,
      bearer: ENV["STAFF_ADMIN_TOKEN"],
      content_type: "application/vnd.api+json",
      accept: "application/vnd.api+json; version=2")
  end

  def log_prefix
    subj_id = data["data"]["attributes"]["subjId"]
    relation_type_id = data["data"]["attributes"]["relationTypeId"]
    obj_id = data["data"]["attributes"]["objId"]

    "[EventImportWorker] #{subj_id} #{relation_type_id} #{obj_id}"
  end

  def handle_logging(response)
    if response.status == 200 || response.status == 201
      Rails.logger.info("#{log_prefix} pushed to the Event Data service.")
    elsif response.status == 409
      Rails.logger.info("#{log_prefix} already pushed to the Event Data service.")
    elsif response.body["errors"].present?
      Rails.logger.error("#{log_prefix} had an error: #{response.body["errors"]}")
      Rails.logger.error(data.inspect)
    end
  end
end
