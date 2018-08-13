module Queue
  def queue options={}
    puts "Queue name has not been specified" unless ENV['ENVIRONMENT'].present?
    puts "AWS_REGION has not been specified" unless ENV['AWS_REGION'].present?
    region = ENV['AWS_REGION'] ||= 'eu-west-1'
    Aws::SQS::Client.new(region: region.to_s, stub_responses: false)
  end

  def get_total options={}
    req = @sqs.get_queue_attributes(
      {
        queue_url: queue_url, attribute_names: 
          [
            'ApproximateNumberOfMessages', 
            'ApproximateNumberOfMessagesNotVisible'
          ]
      }
    )

    msgs_available = req.attributes['ApproximateNumberOfMessages']
    msgs_in_flight = req.attributes['ApproximateNumberOfMessagesNotVisible']
    msgs_available.to_i
  end

  def get_message options={}
    @sqs.receive_message(queue_url: queue_url, max_number_of_messages: 1, wait_time_seconds: 1)
  end

  def delete_message options={}
    return 1 if options.messages.size < 1
    reponse = @sqs.delete_message({
      queue_url: queue_url,
      receipt_handle: options.messages[0][:receipt_handle]    
    })
    if reponse.successful?
      puts "Message #{options.messages[0][:receipt_handle]} deleted"
      0
    else
      puts "Could NOT delete Message #{options.messages[0][:receipt_handle]}"
      1
    end

  end

  def queue_url options={}
    options[:queue_name] ||= "#{ENV['ENVIRONMENT']}_usage" 
    queue_name = options[:queue_name] 
    # puts "Using  #{@sqs.get_queue_url(queue_name: queue_name).queue_url} queue"
    @sqs.get_queue_url(queue_name: queue_name).queue_url
  end
end