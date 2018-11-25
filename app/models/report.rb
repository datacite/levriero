require 'ffi_yajl'
# require 'json/streamer'


class Report < Base

  COMPRESSED_HASH_MESSAGE = {"code": 69,"severity": "warning","message": "report is compressed using gzip","help-url": "https://github.com/datacite/sashimi","data": "usage data needs to be uncompressed"}
  
  def initialize report, options={}
    @errors = report.body.fetch("errors") if report.body.fetch("errors", nil).present?
    return @errors if report.body.fetch("errors", nil).present?
    return [{ "errors" => { "title" => "The report is blank" }}] if report.body.blank?

    @data = report.body.fetch("data", {})
    @header = @data.dig("report","report-header")
    @report_id = report.url
    @gzip=""

    if compressed_report?
      puts "compressed"
      @encoded_report = @data.dig("report").fetch("gzip","")
      @checksum  = @data.dig("report").fetch("checksum","")
    end

  end

  def decompress_report 
    ActiveSupport::Gzip.decompress(@gzip)
  end

  def decode_report 
    @gzip = Base64.decode64(@encoded_report)
    decompress_report
  end

  def parse_data 
    return @errors if @data.nil?
    if compressed_report?
      json = decode_report
      options= {symbolize_keys:false}
      parser = Yajl::Parser.new(options)

      json =  json.gsub('\"', '"')[1..-2]
      parser.on_parse_complete = method(:parse_report_datasets)
      pp = parser.parse_chunk(json) 
    else
      json = @data.dig("report")
      parse_report_datasets(json)
    end
  end


  def parse_report_datasets report, options={}
    Array.wrap(report["report-datasets"]).reduce([]) do |x, item|
      next unless item.respond_to?("dig")
      next unless item.fetch("dataset-id",nil)
      puts item
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
    return nil unless @data.dig("report","report-header","exceptions").present?
    return nil unless @data.dig("report","report-header","exceptions").any?
    @data.dig("report","report-header","exceptions").include?(COMPRESSED_HASH_MESSAGE)
  end

  def correct_checksum?
    # Digest::SHA256.hexdigest(decode_report(report))
    puts @checksum
    puts Digest::SHA256.hexdigest(Base64.decode64(@encoded_report))
    return nil if Digest::SHA256.hexdigest(Base64.decode64(@encoded_report)) != @checksum
    true
  end

end
