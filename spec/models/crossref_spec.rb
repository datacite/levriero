require "rails_helper"

describe Crossref, type: :model, vcr: true do
  let(:from_date) { "2023-12-17" }
  let(:until_date) { "2023-12-18" }

  describe ".import_by_month_dates" do
    describe "returns the correct dates" do
      it "when dates are provided" do
        options = {
          from_date: from_date,
          until_date: until_date
        }

        expect(Crossref.import_by_month_dates(options)).to(eq({
          from_date: Date.parse("2023-12-01"),
          until_date: Date.parse("2023-12-31")
        }))
      end

      it "when dates are not provided" do
        allow(Date).to(receive(:current).and_return(Date.parse("2023-01-12")))

        from_date = nil
        until_date = nil

        expect(Crossref.import_by_month_dates).to(eq({
          from_date: Date.parse("2023-01-01"),
          until_date: Date.parse("2023-01-31")
        }))
      end
    end
  end

  describe ".import_dates" do
    describe "returns the correct dates" do
      it "when dates are provided" do
        options = {
          from_date: from_date,
          until_date: until_date
        }

        expect(Crossref.import_dates(options)).to(eq({
          from_date: Date.parse(from_date),
          until_date: Date.parse(until_date)
        }))
      end

      it "when dates are not provided" do
        allow(Date).to(receive(:current).and_return(Date.parse("2023-01-12")))

        from_date = nil
        until_date = nil

        expect(Crossref.import_dates).to(eq({
          from_date: Date.parse("2023-01-11"),
          until_date: Date.parse("2023-01-12")
        }))
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
      query_url = crossref.get_query_url(from_date: from_date, until_date: until_date, cursor: "abc123")
      expect(query_url).to include("from-updated-time=#{from_date}")
      expect(query_url).to include("until-updated-time=#{until_date}")
      expect(query_url).to include("cursor=abc123")
      expect(query_url).to include("not-asserted-by=https%3A%2F%2Fror.org%2F04wxnsj81")
      expect(query_url).to include("object.registration-agency=DataCite")
    end
  end

  describe "#queue_jobs" do
    context "when there are DOIs to import" do
      it "queues jobs and returns the total number of works queued" do
        allow_any_instance_of(Crossref).to receive(:process_data).and_return([5, nil])

        response = Crossref.new.queue_jobs(from_date: from_date, until_date: until_date)

        expect(response).to eq(5)
      end

      it "sends a Slack notification when slack_webhook_url is present" do
        allow_any_instance_of(Crossref).to receive(:process_data).and_return([1, nil])

        allow(Rails.logger).to receive(:info)

        # Stubbing HTTP request to the Slack webhook
        stub_request(:post, /slack_webhook_url/).to_return(status: 200, body: "", headers: {})

        expect_any_instance_of(Crossref).to receive(:send_notification_to_slack)

        Crossref.new.queue_jobs(slack_webhook_url: "https://example.com/slack_webhook")
      end
    end

    context "when there are no DOIs to import" do
      it "returns 0 and logs a message when there are no DOIs to import" do
        allow_any_instance_of(Crossref).to receive(:process_data).and_return([0, nil])

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
