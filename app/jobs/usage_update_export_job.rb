class UsageUpdateExportJob < ActiveJob::Base
  queue_as :levriero

  def perform(item, options={})
    logger = Logger.new(STDOUT)
    logger.info item
    response = UsageUpdate.push_item(item, options)
    send_message(response,{slack_webhook_url: ENV['SLACK_WEBHOOK_URL']})

  end


  def send_message response, options={}
    logger = Logger.new(STDOUT)
    if response.status == 201 
      text =  "[Event Data] #{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} pushed to Event Data service."
    elsif response.status == 200
      text = "[Event Data] #{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} pushed to Event Data service for update."
    elsif response.body["errors"].present?
      text = "[Event Data] #{item['subj-id']} #{item['relation-type-id']} #{item['obj-id']} had an error: #{response.body['errors'].first['title']}"
    end

    logger.info text

    # if options[:slack_webhook_url].present?
    #   attachment = {
    #     title: options[:title] || "Report",
    #     text: text,
    #     color: options[:level] || "good"
    #   }
    #   notifier = Slack::Notifier.new options[:slack_webhook_url],
    #                                   username: "Event Data Agent",
    #                                   icon_url: ICON_URL
    #   notifier.post attachments: [attachment]
    # end
  end
end