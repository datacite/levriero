require "rails_helper"

describe ZbmathSoftware, type: :model, vcr: true do
  let(:from_date) { "2025-02-01T00:00:00Z" }
  let(:until_date) { "2025-02-02T12:00:00Z" }

  describe ".import_by_month" do
    context "with valid date range" do
      it "queues jobs for DOIs created within the specified month range" do
        response = ZbmathSoftware.import_by_month(from_date: from_date, until_date: until_date)
        expect(response).to eq("Queued import for ZBMath Software Records updated from 2025-02-01T00:00:00+00:00 until 2025-02-28T23:59:59+00:00.")
      end
    end

    context "with missing date range" do
      it "queues jobs with default dates (current month)" do
        # Stub Date to be fixed
        allow(Date).to receive(:current).and_return(Date.new(2024, 12, 2))

        date_spy = spy("Date")
        allow(Date).to receive(:parse).and_wrap_original do |original_method, *args|
          date_spy.parse(*args)
          original_method.call(*args)
        end
        response = ZbmathSoftware.import_by_month
        expect(response).to eq("Queued import for ZBMath Software Records updated from 2024-12-01 until 2024-12-31.")
      end
    end
  end

  describe ".import" do
    context "with valid date range" do
      it "queues jobs for DOIs updated within the specified date range" do
        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathSoftware.import(from_date: from_date, until_date: until_date)
        expect(response).to be_a(Integer).and be >= 0
        expect(logger_spy).to have_received(:info).with("Importing ZBMath Software Records updated from 2025-02-01T00:00:00+00:00 until 2025-02-02T12:00:00+00:00.")
      end
    end

    context "with missing date range" do
      it "queues jobs with default date range (yesterday-today)" do
        # Stub Date to be fixed
        allow(Date).to receive(:current).and_return(Date.new(2025, 2, 2))

        date_spy = spy("Date")
        allow(Date).to receive(:parse).and_wrap_original do |original_method, *args|
          date_spy.parse(*args)
          original_method.call(*args)
        end

        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathSoftware.import
        expect(response).to be_a(Integer).and be >= 0
        expect(logger_spy).to have_received(:info).with("Importing ZBMath Software Records updated from 2025-02-01 until 2025-02-02.")
      end
    end

    context "when there are no updated records" do
      it "catches the OAI error and returns a message" do
        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathSoftware.import(options = {from_date: "1990-01-01", until_date: "1990-01-02"})
        expect(response).to eq(nil)
        expect(logger_spy).to have_received(:info).with("Importing ZBMath Software Records updated from 1990-01-01T00:00:00+00:00 until 1990-01-02T00:00:00+00:00.")
        expect(logger_spy).to have_received(:info).with("No ZBMath Software records updated between 1990-01-01T00:00:00+00:00 and 1990-01-02T00:00:00+00:00.")
      end
    end
  end

  describe "#source_id" do
    it "returns the source_id" do
      zbmath = ZbmathSoftware.new
      expect(zbmath.source_id).to eq("zbmath")
    end
  end

  describe "#process_zbmath_record" do
    context "when there are relationships to DataCite DOIs" do
      it "sends a message to the events queue" do
        allow(ZbmathSoftware).to(receive(:send_event_import_message).and_return(nil))
        allow(ZbmathSoftware).to(receive(:cached_crossref_response).and_return({obj: "obj"}))
        allow(ZbmathSoftware).to(receive(:cached_datacite_response).and_return({subj: "subj"}))

        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathSoftware.process_zbmath_record("oai:swmath.org:2901")

        expect(response).to be_a(Integer).and eq 5
        expect(logger_spy).to have_received(:info).with("[Event Data] https://swmath.org/software/2901 is_cited_by https://doi.org/10.48550/arxiv.2108.00739 sent to the events queue.")
        expect(logger_spy).to have_received(:info).with("[Event Data] https://swmath.org/software/2901 is_cited_by https://doi.org/10.48550/arxiv.1907.12345 sent to the events queue.")
        expect(logger_spy).to have_received(:info).with("[Event Data] https://swmath.org/software/2901 is_cited_by https://doi.org/10.48550/arxiv.2008.02931 sent to the events queue.")
        expect(logger_spy).to have_received(:info).with("[Event Data] https://swmath.org/software/2901 is_cited_by https://doi.org/10.48550/arxiv.1607.04459 sent to the events queue.")
        expect(logger_spy).to have_received(:info).with("[Event Data] https://swmath.org/software/2901 is_cited_by https://doi.org/10.48550/arxiv.2112.10201 sent to the events queue.")
      end
    end
    context "with there are no relationships to DataCite DOIs" do
      it "doesn't send any messages to the events queue" do
        allow(ZbmathSoftware).to(receive(:send_event_import_message).and_return(nil))
        allow(ZbmathSoftware).to(receive(:cached_crossref_response).and_return({obj: "obj"}))
        allow(ZbmathSoftware).to(receive(:cached_datacite_response).and_return({subj: "subj"}))

        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathSoftware.process_zbmath_record("oai:swmath.org:6768")

        expect(response).to be_a(Integer).and eq 0
        expect(logger_spy).not_to have_received(:info)
      end
    end
  end
end