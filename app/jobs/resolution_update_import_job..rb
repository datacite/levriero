class ResolutionUpdateImportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item, options={})
    logger = Logger.new(STDOUT)
    logger.info item
    response = ResolutionUpdate.push_item(item, options)
    item = JSON.parse(item)
    if response.status == 201 
      logger.info "[Event Data] #{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} pushed to Event Data service."
    elsif response.status == 200
      logger.info "[Event Data] #{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} pushed to Event Data service for update."
    elsif response.body["errors"].present?
      logger.info "[Event Data] #{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} had an error: #{response.body['errors'].first['title']}"
    end
  end
end