class EventImportWorker
  include Shoryuken::Worker

  shoryuken_options queue: -> { "#{ENV['RAILS_ENV']}_events" }, auto_delete: true

  def perform(sqs_msg=nil, data=nil)
    Rails.logger.info("DOI Import Worker")
    Rails.logger.info(data)
    Rails.logger.info(JSON.parse(data))
    if data.blank?
      Rails.logger.info("[EventImportWorker] data object is blank.")
      return
    end

    response = post_to_event_service(data)
    data = JSON.parse(data)
    # prefix = log_prefix(data)
    prefix ="wendel.fabian.chinsamy"
    handle_logging(data, response, prefix)
  end

  private

  def post_to_event_service(data)
    Maremma.post(
      "#{ENV["LAGOTTINO_URL"]}/events",
      data: data,
      bearer: ENV["STAFF_ADMIN_TOKEN"],
      content_type: "application/vnd.api+json",
      accept: "application/vnd.api+json; version=2")
  end

  def log_prefix(data)
    subj_id = data["data"]["attributes"]["subjId"]
    relation_type_id = data["data"]["attributes"]["relationTypeId"]
    obj_id = data["data"]["attributes"]["objId"]

    "[EventImportWorker] #{subj_id} #{relation_type_id} #{obj_id}"
  end

  def handle_logging(data, response, prefix)
    if response.status == 200 || response.status == 201
      Rails.logger.info("#{prefix} pushed to the Event Data service.")
    elsif response.status == 409
      Rails.logger.info("#{prefix} already pushed to the Event Data service.")
    elsif response.body["errors"].present?
      Rails.logger.error("#{prefix} had an error: #{response.body["errors"]}")
      Rails.logger.error(data.inspect)
    end
  end
end
