require "rails_helper"

describe Zbmath, type: :model, vcr: true do
  let(:from_date) { "2025-01-01" }
  let(:until_date) { "2025-02-28" }

  describe ".import_by_month" do
    context "with valid date range" do
      it "queues jobs for DOIs created within the specified month range" do
        response = Zbmath.import_by_month(from_date: from_date, until_date: until_date)
        expect(response).to eq("Queued import for ZBMath Records updated from 2025-01-01 until 2025-02-28.")
      end
    end

    context "with missing date range" do
      it "queues jobs with default dates (current month)" do
        # Stub Date to be fixed
        allow(Date).to receive(:current).and_return(Date.new(2025, 1, 2))

        date_spy = spy("Date")
        allow(Date).to receive(:parse).and_wrap_original do |original_method, *args|
          date_spy.parse(*args)
          original_method.call(*args)
        end
        response = Zbmath.import_by_month
        expect(response).to eq("Queued import for ZBMath Records updated from 2025-01-01 until 2025-01-31.")
      end
    end
  end

  describe ".import" do
    context "with valid date range" do
      it "queues jobs for DOIs updated within the specified date range" do
        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = Zbmath.import(from_date: from_date, until_date: until_date)
        expect(response).to be_a(Integer).and be >= 0
        expect(logger_spy).to have_received(:info).with("Importing ZBMath Records updated from 2025-01-01 until 2025-02-28.")
      end
    end

    context "with missing date range" do
      it "queues jobs with default date range (yesterday-today)" do
        # Stub Date to be fixed
        allow(Date).to receive(:current).and_return(Date.new(2025, 1, 2))

        date_spy = spy("Date")
        allow(Date).to receive(:parse).and_wrap_original do |original_method, *args|
          date_spy.parse(*args)
          original_method.call(*args)
        end

        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = Zbmath.import
        expect(response).to be_a(Integer).and be >= 0
        expect(logger_spy).to have_received(:info).with("Importing ZBMath Records updated from 2025-01-01 until 2025-01-02.")
      end
    end

    context "when there are no updated records" do
      it "catches the OAI error and returns a message" do
        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = Zbmath.import(options = {from_date: "1990-01-01", until_date: "1990-01-02"})
        expect(response).to eq(nil)
        expect(logger_spy).to have_received(:info).with("Importing ZBMath Records updated from 1990-01-01 until 1990-01-02.")
        expect(logger_spy).to have_received(:info).with("No ZBMath records updated between 1990-01-01 and 1990-01-02.")
      end
    end
  end

  describe "#source_id" do
    it "returns the source_id" do
      zbmath = Zbmath.new
      expect(zbmath.source_id).to eq("zbmath")
    end
  end

  describe "#parse_zbmath_record" do
    it "sends a message to the events queue" do
      allow(Zbmath).to(receive(:send_event_import_message).and_return(nil))
      allow(Zbmath).to(receive(:cached_crossref_response).and_return({obj: "obj"}))
      allow(Zbmath).to(receive(:cached_datacite_response).and_return({subj: "subj"}))

      logger_spy = spy("logger")
      allow(Rails).to receive(:logger).and_return(logger_spy)

      metadata = File.read("#{fixture_path}oai_zbmath_org_942.xml")
      response = Zbmath.parse_zbmath_record(metadata)

      expect(response).to be_a(Integer).and eq 5
      expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.1007/bf00992697 cites https://doi.org/10.1145/76359.76371 sent to the events queue.")
      expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.1007/bf00992697 is_cited_by https://zbmath.org/946 sent to the events queue.")
      expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.1007/bf00992697 is_authored_by https://zbmath.org/authors/tesauro.gerald sent to the events queue.")
      expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.1007/bf00992697 is_identical_to https://zbmath.org/0772.68075 sent to the events queue.")
      expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.1007/bf00992697 is_identical_to oai:zbmath.org:942 sent to the events queue.")
    end
  end
end