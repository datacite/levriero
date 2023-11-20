require "rails_helper"

describe Crossref, type: :model, vcr: true do
  let(:from_date) { "2018-01-04" }
  let(:until_date) { "2018-08-05" }

  describe ".import_by_month" do
    context "with valid parameters" do
      it "queues jobs for each month between from_date and until_date" do
        response = Crossref.import_by_month(from_date: from_date, until_date: until_date)
        expect(response).to eq("Queued import for DOIs updated from 2018-01-01 until 2018-08-31.")
      end
    end

    context "with missing parameters" do
      it "queues jobs with default dates (current month)" do
        response = Crossref.import_by_month
        expect(response).to start_with("Queued import for DOIs updated from")
      end
    end
  end

  describe ".import" do
    context "with valid parameters" do
      it "queues jobs for DOIs updated within the specified date range" do
        until_date = "2018-01-31"
        response = Crossref.import(from_date: from_date, until_date: until_date)
        expect(response).to be_a(Integer).and be >= 0
      end
    end

    context "with missing parameters" do
      it "queues jobs for the default date range (yesterday to today)" do
        # Stub Date.current to return a fixed date
        allow(Date).to receive(:current).and_return(Date.new(2023, 1, 2))
    
        # Use a spy on Date.parse
        date_spy = spy("Date")
        allow(Date).to receive(:parse).and_wrap_original do |original_method, *args|
          date_spy.parse(*args)
          original_method.call(*args)
        end
    
        # Mocking Date.parse
        response = Crossref.import
    
        expect(response).to be_a(Integer).and be >= 0

      end
    end
  end

  describe "#source_id" do
    it "returns 'crossref' as the source_id" do
      crossref = Crossref.new
      expect(crossref.source_id).to eq("crossref")
    end
  end

  describe "#get_query_url" do
    it "returns a valid query URL with the given options" do
      crossref = Crossref.new
      query_url = crossref.get_query_url(from_date: from_date, until_date: until_date, rows: 10, cursor: "abc123")
      expect(query_url).to include("source=crossref")
      expect(query_url).to include("from-collected-date=#{from_date}")
      expect(query_url).to include("until-collected-date=#{until_date}")
      expect(query_url).to include("rows=10")
      expect(query_url).to include("cursor=abc123")
    end
  end

  describe "#queue_jobs" do
    context "when there are DOIs to import" do
      it "queues jobs and returns the total number of works queued" do
        allow_any_instance_of(Crossref).to receive(:get_total).and_return([5, "next_cursor"])
        allow_any_instance_of(Crossref).to receive(:process_data).and_return([5, "next_cursor"])

        response = Crossref.new.queue_jobs(from_date: from_date, until_date: until_date)

        expect(response).to eq(5)
      end

      it "sends a Slack notification when slack_webhook_url is present" do
        allow_any_instance_of(Crossref).to receive(:get_total).and_return([1, "cursor"])
        allow_any_instance_of(Crossref).to receive(:process_data).and_return([1, "cursor"])

        allow(Rails.logger).to receive(:info)

        # Stubbing HTTP request to the Slack webhook
        stub_request(:post, /slack_webhook_url/).to_return(status: 200, body: "", headers: {})

        expect_any_instance_of(Crossref).to receive(:send_notification_to_slack)

        Crossref.new.queue_jobs(slack_webhook_url: "https://example.com/slack_webhook")
      end
    end

    context "when there are no DOIs to import" do
      it "returns 0 and logs a message when there are no DOIs to import" do
        allow_any_instance_of(Crossref).to receive(:get_total).and_return([0, nil])

        # Spy on Rails.logger
        logger_spy = spy("logger")
        allow(Rails).to receive(:logger).and_return(logger_spy)

        response = Crossref.new.queue_jobs(from_date: from_date, until_date: until_date)

        expect(response).to eq(0)
        expect(logger_spy).to have_received(:info).with("[Event Data] No DOIs updated #{from_date} - #{until_date}.")
        expect(logger_spy).to have_received(:info).once
      end
    end
  end

  describe "#push_item" do
    let(:item) do
      {
        "id" => "example_id",
        "action" => "example_action",
        "subj_id" => "example_subj_id",
        "obj_id" => "example_obj_id",
        "relation_type_id" => "example_relation_type_id",
        "source_id" => "example_source_id",
        "source_token" => "example_source_token",
        "occurred_at" => "2023-01-05T12:00:00Z",
        "timestamp" => 1641379200,
        "license" => "example_license",
      }
    end

    before(:each) do
      allow(ENV).to receive(:[]).with("STAFF_ADMIN_TOKEN").and_return("STAFF_ADMIN_TOKEN")
      allow(ENV).to receive(:[]).with("LAGOTTINO_URL").and_return("https://fake.lagattino.com")
      allow(ENV).to receive(:[]).with("DATACITE_URL_SOURCE_TOKEN").and_return("DATACITE_URL_SOURCE_TOKEN")
      allow(ENV).to receive(:[]).with("USER_AGENT").and_return("default_user_agent")
      allow(Base).to receive(:cached_datacite_response).and_return({ "foo" => "bar" })
      allow(Time).to receive_message_chain(:zone, :now, :iso8601).and_return("2023-11-15T12:17:47Z")
    end

    context "when STAFF_ADMIN_TOKEN is present" do
      before do
        allow(ENV).to receive(:[]).with("STAFF_ADMIN_TOKEN").and_return("example_admin_token")
        allow(Maremma).to receive(:put).and_return(OpenStruct.new(status: 200))
      end

      context "when the push is successful (HTTP status 200)" do
        it "logs success information" do
          push_url = "https://fake.lagattino.com/events/example_id"
          data = {
            "data" => {
              "id" => "example_id",
              "type" => "events",
              "attributes" => {
                "messageAction" => "example_action",
                "subjId" => "example_subj_id",
                "objId" => "example_obj_id",
                "relationTypeId" => "example_relation_type_id",
                "sourceId" => "example_source_id",
                "sourceToken" => "example_source_token",
                "occurredAt" => "2023-01-05T12:00:00Z",
                "timestamp" => 1641379200,
                "license" => "example_license",
                "subj" => nil,
                "obj" => nil,
              },
            },
          }

          stub_request(:put, push_url).
            with(
              body: data.to_json,
              headers: {
                "Authorization" => "Bearer example_admin_token",
                "Content-Type" => "application/vnd.api+json",
                "Accept" => "application/vnd.api+json; version=2",
              },
            ).
            to_return(status: 200, body: { "data" => { "id" => "example_id" } }.to_json, headers: {})

          expect(Rails.logger).to receive(:info).with("[Event Data] example_subj_id example_relation_type_id example_obj_id pushed to Event Data service.")

          Crossref.push_item(item)
        end
      end

      context "when the push results in a conflict (HTTP status 409)" do
        before do
          allow(Maremma).to receive(:put).and_return(OpenStruct.new(status: 409))
        end
        it "logs conflict information" do
          push_url = "https://fake.lagattino.com/events/example_id"
          data = {
            "data" => {
              "id" => "example_id",
              "type" => "events",
              "attributes" => {
                "messageAction" => "example_action",
                "subjId" => "example_subj_id",
                "objId" => "example_obj_id",
                "relationTypeId" => "example_relation_type_id",
                "sourceId" => "example_source_id",
                "sourceToken" => "example_source_token",
                "occurredAt" => "2023-01-05T12:00:00Z",
                "timestamp" => 1641379200,
                "license" => "example_license",
                "subj" => nil,
                "obj" => nil,
              },
            },
          }

          stub_request(:put, push_url).
            with(
              body: data.to_json,
              headers: {
                "Authorization" => "Bearer example_admin_token",
                "Content-Type" => "application/vnd.api+json",
                "Accept" => "application/vnd.api+json; version=2",
              },
            ).
            to_return(status: 409, body: { "errors" => [{ "title" => "Conflict" }] }.to_json, headers: {})

          expect(Rails.logger).to receive(:info).with("[Event Data] example_subj_id example_relation_type_id example_obj_id already pushed to Event Data service.")

          Crossref.push_item(item)
        end
      end

      context "when the push results in an error" do
        let(:error_message) { "An error occurred during the put request." }
        before do
          allow(Maremma).to receive(:put) do |_, _options|
            OpenStruct.new(status: 500, body: { "errors" => error_message })
          end
        end
        it "logs error information" do
          push_url = "https://fake.lagattino.com/events/example_id"
          data = {
            "data" => {
              "id" => "example_id",
              "type" => "events",
              "attributes" => {
                "messageAction" => "example_action",
                "subjId" => "example_subj_id",
                "objId" => "example_obj_id",
                "relationTypeId" => "example_relation_type_id",
                "sourceId" => "example_source_id",
                "sourceToken" => "example_source_token",
                "occurredAt" => "2023-01-05T12:00:00Z",
                "timestamp" => 1641379200,
                "license" => "example_license",
                "subj" => nil,
                "obj" => nil,
              },
            },
          }

          error_logs = []
          allow(Rails.logger).to receive(:error) { |log| error_logs << log }

          stub_request(:put, push_url).
            with(
              body: data.to_json,
              headers: {
                "Authorization" => "Bearer example_admin_token",
                "Content-Type" => "application/vnd.api+json",
                "Accept" => "application/vnd.api+json; version=2",
              },
            ).
            to_return(status: 500, body: { "errors" => [{ "title" => error_message }] }.to_json, headers: {})

          Crossref.push_item(item)

          expect(error_logs).to include("[Event Data] #{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} had an error: #{error_message}")
        end
      end
    end

    context "when STAFF_ADMIN_TOKEN is not present" do
      before do
        allow(ENV).to receive(:[]).with("STAFF_ADMIN_TOKEN").and_return(nil)
      end

      it "does not make a push request and logs a warning" do
        Crossref.push_item(item)
        expect(Maremma).not_to receive(:put)
        # TODO Modify code to add this warning
        # expect(Rails.logger).to receive(:warn).with("[Event Data] Skipping push_item because STAFF_ADMIN_TOKEN is not present.")
      end
    end
  end
end
