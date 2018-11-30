module Parserable
  extend ActiveSupport::Concern

  # included do

  module ClassMethods

    def correct_checksum? encoded_report, checksum
      puts checksum
      puts Digest::SHA256.hexdigest(Base64.decode64(encoded_report))
      return nil if Digest::SHA256.hexdigest(Base64.decode64(encoded_report)) != checksum
      true
    end

    def decompress_report gzip
      ActiveSupport::Gzip.decompress(gzip)
    end
  
    def decode_report encoded_report
      Base64.decode64(encoded_report)
    end

    def parse_subset json
      # puts json
      parser = Yajl::Parser.new
      # json =  @type == "rd1" ? json : json.gsub('\"', '"')[1..-2]
      # json =  @type == "rd1" ? json : json.gsub('\n', '')
      pp= parser.parse(json)
      pp.fetch("report-datasets",[])
    end


    # def report_type?
    #   return "normal" unless @data.dig("report","report-header","exceptions").present?
    #   return "normal" unless @data.dig("report","report-header","exceptions").any?
    #   exceptions = @data.dig("report","report-header","exceptions") 


    # end

    # def subsetted_report?

    #   code = exceptions.first.fetch("code","")
    #   if code == 69
    #     true
    #   else
    #     nil
    #   end
  
    # end

  end
end
