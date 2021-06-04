class UsageUpdateExportJob < ApplicationJob
  queue_as :levriero_usage

  def perform(item, options = {})
    response = UsageUpdate.push_item(item, options)
    item = JSON.parse(item)
    if response.status == 201
      Rails.logger.info "[Event Data] #{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} pushed to Event Data service."
    elsif response.status == 200
      Rails.logger.info "[Event Data] #{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} pushed to Event Data service for update."
    elsif response.body["errors"].present?
      Rails.logger.error "[Event Data] #{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} had an error: #{response.body['errors'].first['title']}"
      Rails.logger.error item.inspect
    end
  end
end
