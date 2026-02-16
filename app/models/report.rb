class Report < Base
  attr_reader :data, :header, :release, :report_id, :type, :errors, :datasets,
              :subsets, :report_url

  include Parserable

  COMPRESSED_HASH_MESSAGE = { "code" => 69, "severity" => "warning",
                              "message" => "Report is compressed using gzip", "help-url" => "https://github.com/datacite/sashimi", "data" => "usage data needs to be uncompressed" }.freeze

  def initialize(report, _options = {})
    @errors = report.body.fetch("errors") if report.body.fetch("errors",
                                                               nil).present?
    return @errors if report.body.fetch("errors", nil).present?
    return [{ "errors" => { "title" => "The report is blank" } }] if report.body.blank?

    @data = report.body.fetch("data", {})
    @header = @data.dig("report", "report-header")
    @release = @header["release"]
    @datasets = @data.dig("report", "report-datasets")
    @subsets = @data.dig("report", "report-subsets")
    @report_id = @data.dig("report", "id")
    @report_url = report.url
    @type = get_type
  end

  def self.parse_multi_subset_report(report)
    url = case true
          when Rails.env.production?
            "https://api.datacite.org/reports/#{report.report_id}"
          when ENV["API_URL"].include?("test")
            "https://api.test.datacite.org/reports/#{report.report_id}"
          else
            "https://api.stage.datacite.org/reports/#{report.report_id}"
          end

    subsets = report.subsets
    all_datasets = []

    subsets.each do |subset|
      compressed = decode_report subset["gzip"]
      json = decompress_report compressed
      dataset_array = parse_subset json

      dataset_array.map do |dataset|
        args = { header: report.header, url: url }
        UsageUpdateParseJob.perform_later(dataset, args)
      end

      all_datasets.concat(dataset_array)
    end

    all_datasets
  end

  def self.parse_normal_report(report)
    json = report.data.dig("report", "report-datasets")
    # hsh = parse_subset json
    json.map do |dataset|
      args = { header: report.header, url: report.report_url }
      UsageUpdateParseJob.perform_later(dataset, args)
    end
    # UsageUpdateParseJob.perform_async(report.report_url, json)
    json
  end

  def self.translate_datasets(items, options)
    return [] if items.nil?

    # return @errors if @data.nil?
    # return @errors if @errors

    Array.wrap(items).reduce([]) do |x, item|
      data = {
        doi: item["dataset-id"].first["value"],
        id: normalize_doi(item["dataset-id"].first["value"]),
        created: options[:header].fetch("created"),
        report_url: options[:url],
        created_at: options[:header].dig("reporting-period", "begin-date"),
      }
      instances = item.dig("performance", 0, "instance")

      return x += [OpenStruct.new(body: { "errors" => "There are too many instances in #{data[:doi]} for report #{options[:url]}. There can only be 4" })] if instances.size > 8

      x += Array.wrap(instances).reduce([]) do |ssum, instance|
        data[:count] = instance["count"]
        event_type = "#{instance['metric-type']}-#{instance['access-method']}"
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
    return nil if @data.dig("report", "report-header",
                            "exceptions").blank?
    return nil unless @data.dig("report", "report-header", "exceptions").any?

    exceptions = @data.dig("report", "report-header", "exceptions")
    codes = exceptions.map { |exception| exception.fetch("code", "") }

    codes.include?(69)
  end

  # def correct_checksum?
  #   # Digest::SHA256.hexdigest(decode_report(report))
  #   puts @checksum
  #   puts Digest::SHA256.hexdigest(Base64.decode64(@encoded_report))
  #   return nil if Digest::SHA256.hexdigest(Base64.decode64(@encoded_report)) != @checksum
  #   true
  # end
end
