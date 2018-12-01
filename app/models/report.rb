class Report < Base
  attr_reader :data, :header, :release, :report_id, :type, :errors, :datasets, :subsets, :report_url
  include Parserable

  COMPRESSED_HASH_MESSAGE = {"code"=>69, "severity"=>"warning", "message"=>"Report is compressed using gzip", "help-url"=>"https://github.com/datacite/sashimi", "data"=>"usage data needs to be uncompressed"}

  def initialize report, options={}
    @errors = report.body.fetch("errors") if report.body.fetch("errors", nil).present?
    return @errors if report.body.fetch("errors", nil).present?
    return [{ "errors" => { "title" => "The report is blank" }}] if report.body.blank?

    @data = report.body.fetch("data", {})
    @header = @data.dig("report","report-header")
    @release = @data.dig("report","report-header","release")
    @datasets = @data.dig("report","report-datasets")
    @subsets = @data.dig("report","report-subsets")
    @report_id = @data.dig("report","id")
    @report_url = report.url
    # @gzip=""
    @type = get_type

    
    # if compressed_report?
    #   # @encoded_report = @data.dig("report").fetch("gzip","")
    #   # @checksum  = @data.dig("report").fetch("checksum","")
    #   # @items = build_report_datasets
    # else
    #   # @items = @data.dig("report","report-datasets")
    # end
  end

  # def decompress_report 
  #   ActiveSupport::Gzip.decompress(@gzip)
  # end

  # def decode_report 
  #   @gzip = Base64.decode64(@encoded_report)
  #   decompress_report
  # end

  # def build_report_datasets
  #   unless correct_checksum?
  #     @errors = [{"errors": "checksum does not match"}]
  #     return []
  #   end

  #   json = decode_report
  #   parser = Yajl::Parser.new
  #   json =  @release == "rd1" ? json : json.gsub('\"', '"')[1..-2]
  #   json =  @release == "rd1" ? json : json.gsub('\n', '')
  #   pp= parser.parse(json)
  #   pp.fetch("report-datasets",[])
  # end

  def self.parse_multi_subset_report report
    subset = report.subsets.last
    # maybe just parse the last subset as th other ones owuld have been parsed already
    # subsets.map do |subset|
    #   puts subset["checksum"]
    #   compressed = decode_report subset["gzip"]
    #   json = decompress_report compressed
    #   # unless correct_checksum? subset["gzip"], subset["checksum"]
    #   #   @errors = [{"errors": "checksum does not match"}]
    #   #   json = []
    #   # end
    #   dataset_array = parse_subset json
    #   # print "1"
    #   UsageUpdateParseJob.perform_later(report.report_id, dataset_array)
    #   dataset_array
    # end
      puts subset["checksum"]
      compressed = decode_report subset["gzip"]
      json = decompress_report compressed
      dataset_array = parse_subset json
      UsageUpdateParseJob.perform_later(report.report_url, dataset_array)
      dataset_array
  end
  

  # def parse_compressed_report
  #   unless correct_checksum?
  #     @errors = [{"errors": "checksum does not match"}]
  #     return []
  #   end

  #   json = decode_report
  #   parse_subset json
  # end

  def self.parse_normal_report report
    json = report.data.dig("report","report-datasets")
    # hsh = parse_subset json
    UsageUpdateParseJob.perform_later(report.report_url, json)
    json
  end

  def translate_datasets items, options={}
    return @errors if @data.nil?
    return @errors if items.nil?
    return @errors if @errors

    Array.wrap(items).reduce([]) do |x, item|
      data = { 
        doi: item.dig("dataset-id").first.dig("value"), 
        id: normalize_doi(item.dig("dataset-id").first.dig("value")),
        created: @header.fetch("created"), 
        report_url: @report_url,
        created_at: @header.fetch("created")
      }
      instances = item.dig("performance", 0, "instance")

      return x += [OpenStruct.new(body: { "errors" => "There are too many instances in #{data[:doi]} for report #{@report_url}. There can only be 4" })] if instances.size > 8
   
      x += Array.wrap(instances).reduce([]) do |ssum, instance|
        data[:count] = instance.dig("count")
        event_type = "#{instance.dig("metric-type")}-#{instance.dig("access-method")}"
        ssum << UsageUpdate.format_event(event_type, data, options)
        ssum
      end
    end    
  end

  def get_type
    return "compressed" if compressed_report?
    "normal"
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

  # def correct_checksum?
  #   # Digest::SHA256.hexdigest(decode_report(report))
  #   puts @checksum
  #   puts Digest::SHA256.hexdigest(Base64.decode64(@encoded_report))
  #   return nil if Digest::SHA256.hexdigest(Base64.decode64(@encoded_report)) != @checksum
  #   true
  # end

end
