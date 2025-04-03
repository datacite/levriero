require "rails_helper"

describe ZbmathArticle, type: :model, vcr: true do
  let(:from_date) { "2025-01-01" }
  let(:until_date) { "2025-02-28" }

  describe ".import_by_month" do
    context "with valid date range" do
      it "queues jobs for DOIs created within the specified month range" do
        response = ZbmathArticle.import_by_month(from_date: from_date, until_date: until_date)
        expect(response).to eq("Queued import for ZBMath Article Records updated from 2025-01-01T00:00:00+00:00 until 2025-02-28T23:59:59+00:00.")
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
        response = ZbmathArticle.import_by_month
        expect(response).to eq("Queued import for ZBMath Article Records updated from 2025-01-01 until 2025-01-31.")
      end
    end
  end

  describe ".import" do
    context "with valid date range" do
      it "queues jobs for DOIs updated within the specified date range" do
        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathArticle.import(from_date: from_date, until_date: until_date)
        expect(response).to be_a(Integer).and be >= 0
        expect(logger_spy).to have_received(:info).with("Importing ZBMath Article Records updated from 2025-01-01T00:00:00+00:00 until 2025-02-28T00:00:00+00:00.")
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

        response = ZbmathArticle.import
        expect(response).to be_a(Integer).and be >= 0
        expect(logger_spy).to have_received(:info).with("Importing ZBMath Article Records updated from 2025-01-01 until 2025-01-02.")
      end
    end

    context "when there are no updated records" do
      it "catches the OAI error and returns nil" do
        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathArticle.import(options = {from_date: "1990-01-01", until_date: "1990-01-02"})
        expect(response).to eq(nil)
        expect(logger_spy).to have_received(:info).with("Importing ZBMath Article Records updated from 1990-01-01T00:00:00+00:00 until 1990-01-02T00:00:00+00:00.")
        expect(logger_spy).to have_received(:info).with("No ZBMath Article records updated between 1990-01-01T00:00:00+00:00 and 1990-01-02T00:00:00+00:00.")
      end
    end
  end

  describe "#source_id" do
    it "returns the source_id" do
      zbmath = ZbmathArticle.new
      expect(zbmath.source_id).to eq("zbmath")
    end
  end

  describe "#process_zbmath_record" do
    context "with a DataCite DOI as the main DOI" do
      it "sends a message to the events queue" do
        allow(ZbmathArticle).to(receive(:send_event_import_message).and_return(nil))
        allow(ZbmathArticle).to(receive(:cached_crossref_response).and_return({obj: "obj"}))
        allow(ZbmathArticle).to(receive(:cached_datacite_response).and_return({subj: "subj"}))

        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathArticle.process_zbmath_record("oai:zbmath.org:902693786")

        expect(response).to be_a(Integer).and eq 6
        expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.48550/arxiv.2503.15705 is_authored_by https://zbmath.org/authors/sergeant-perthuis.gregoire sent to the events queue.")
        expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.48550/arxiv.2503.15705 is_authored_by https://zbmath.org/authors/smithe.toby-st-clere sent to the events queue.")
        expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.48550/arxiv.2503.15705 is_authored_by https://zbmath.org/authors/boitel.leo sent to the events queue.")
        expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.48550/arxiv.2503.15705 is_identical_to https://zbmath.org/arXiv:2503.15705 sent to the events queue.")
        expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.48550/arxiv.2503.15705 is_identical_to oai:zbmath.org:902693786 sent to the events queue.")
        expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.48550/arxiv.2503.15705 is_identical_to https://zbmath.org/902693786 sent to the events queue.")
      end
    end
    context "with a non-DataCite DOI as the main DOI" do
      it "sends a message to the events queue for Related Identifiers" do
        allow(ZbmathArticle).to(receive(:send_event_import_message).and_return(nil))
        allow(ZbmathArticle).to(receive(:cached_crossref_response).and_return({obj: "obj"}))
        allow(ZbmathArticle).to(receive(:cached_datacite_response).and_return({subj: "subj"}))

        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathArticle.process_zbmath_record("oai:zbmath.org:7857807")

        expect(response).to be_a(Integer).and eq 1
        expect(logger_spy).to have_received(:info).with("[Event Data] https://doi.org/10.1007/978-981-97-1235-9_2 cites https://doi.org/10.13154/tosc.v2018.i3.93-123 sent to the events queue.")
      end
      it "doesn't send any messages when there are no relevant identifiers" do
        allow(ZbmathArticle).to(receive(:send_event_import_message).and_return(nil))
        allow(ZbmathArticle).to(receive(:cached_crossref_response).and_return({obj: "obj"}))
        allow(ZbmathArticle).to(receive(:cached_datacite_response).and_return({subj: "subj"}))

        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = ZbmathArticle.process_zbmath_record("oai:zbmath.org:942")

        expect(response).to be_a(Integer).and eq 0
      end
    end
  end
end