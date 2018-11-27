class Report < Base

  COMPRESSED_HASH_MESSAGE = {"code"=>69, "severity"=>"warning", "message"=>"Report is compressed using gzip", "help-url"=>"https://github.com/datacite/sashimi", "data"=>"usage data needs to be uncompressed"}

  def initialize report, options={}
    @errors = report.body.fetch("errors") if report.body.fetch("errors", nil).present?
    return @errors if report.body.fetch("errors", nil).present?
    return [{ "errors" => { "title" => "The report is blank" }}] if report.body.blank?

    @data = report.body.fetch("data", {})
    @header = @data.dig("report","report-header")
    @type = @data.dig("report","report-header","release")
    @report_id = report.url
    @gzip=""

    
    if compressed_report?
      @encoded_report = @data.dig("report").fetch("gzip","")
      @checksum  = @data.dig("report").fetch("checksum","")
      @items = parse_report_datasets
    else
      @items = @data.dig("report","report-datasets")
    end
  end

  def decompress_report 
    ActiveSupport::Gzip.decompress(@gzip)
  end

  def decode_report 
    @gzip = Base64.decode64(@encoded_report)
    decompress_report
  end

  def parse_report_datasets
    unless correct_checksum?
      @errors = [{"errors": "checksum does not match"}]
      return []
    end

    json = decode_report
    parser = Yajl::Parser.new
    json =  @type == "rd1" ? json : json.gsub('\"', '"')[1..-2]
    json =  @type == "rd1" ? json : json.gsub('\n', '')
    pp= parser.parse(json)
    pp.fetch("report-datasets",[])
  end

  def parse_data options={}
    return @errors if @data.nil?
    return @errors if @errors

    # items = @data.fetch("report",{}).key?("gzip") ? parse_report_datasets : @data.dig("report","report-datasets")

    Array.wrap(@items).reduce([]) do |x, item|
      data = { 
        doi: item.dig("dataset-id").first.dig("value"), 
        id: normalize_doi(item.dig("dataset-id").first.dig("value")),
        created: @header.fetch("created"), 
        report_id: @report_id,
        created_at: @header.fetch("created")
      }
      instances = item.dig("performance", 0, "instance")

      return x += [OpenStruct.new(body: { "errors" => "There are too many instances in #{data[:doi]} for report #{@report_id}. There can only be 4" })] if instances.size > 8
   
      x += Array.wrap(instances).reduce([]) do |ssum, instance|
        data[:count] = instance.dig("count")
        event_type = "#{instance.dig("metric-type")}-#{instance.dig("access-method")}"
        ssum << UsageUpdate.format_event(event_type, data, options)
        ssum
      end
    end    
  end

  def compressed_report?
    puts @data.dig("report","report-header","exceptions")
    return nil unless @data.dig("report","report-header","exceptions").present?
    return nil unless @data.dig("report","report-header","exceptions").any?
    # @data.dig("report","report-header","exceptions").include?(COMPRESSED_HASH_MESSAGE)
    exceptions = @data.dig("report","report-header","exceptions") 
    code = exceptions.first.fetch("code","")
    if code == 69
      true
    else
      nil
    end

  end

  def correct_checksum?
    # Digest::SHA256.hexdigest(decode_report(report))
    puts @checksum
    puts Digest::SHA256.hexdigest(Base64.decode64(@encoded_report))
    return nil if Digest::SHA256.hexdigest(Base64.decode64(@encoded_report)) != @checksum
    true
  end

end
