require "rails_helper"

describe EventImportWorker do
  describe "#perform" do
    context "when data is blank" do
      before do
        allow(Rails.logger).to(receive(:info))
        allow(Maremma).to(receive(:post).and_return(OpenStruct.new(status: 200)))
      end

      it "a POST request is not made to the event data service" do
        expect(Maremma).not_to(receive(:post))
        EventImportWorker.new.perform(nil, nil)
      end

      it "logs 'blank data message'" do
        expect(Rails.logger).to(receive(:info).with("[EventImportWorker] data object is blank."))
        EventImportWorker.new.perform(nil, nil)
      end
    end

    context "when processing can occur" do
      let(:data) {
        {
          "data" => {
            "type" => "events",
            "attributes" => {
              "messageAction" => "create",
              "subjId" => "https://doi.org/10.0001/foo.bar",
              "objId" => "https://doi.org/10.0001/example.one",
              "relationTypeId" => "example-one",
              "sourceId" => "datacite-url",
              "sourceToken" => "DATACITE_URL_SOURCE_TOKEN",
              "occurredAt" => "2023-11-15",
              "timestamp" => "2023-11-15T12:17:47Z",
              "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
              "subj" => { "foo" => "bar" },
              "obj" => {},
            },
          },
        }
      }

      let(:subj_id) { "https://doi.org/10.0001/foo.bar" }
      let(:relation_type_id) { "example-one" }
      let(:obj_id) { "https://doi.org/10.0001/example.one" }

      before do
        allow(ENV).to(receive(:[]).with("STAFF_ADMIN_TOKEN").and_return("STAFF_ADMIN_TOKEN"))
        allow(ENV).to(receive(:[]).with("LAGOTTINO_URL").and_return("https://fake.lagattino.com"))
      end

      it "a POST request is made to the event data service" do
        allow(Rails.logger).to(receive(:info))
        allow(Maremma).to(receive(:post).and_return(OpenStruct.new(status: 200)))
        expect(Maremma).to(receive(:post))
        EventImportWorker.new.perform(nil, data)
      end

      context "and response is 200" do
        it "logs pushed to event data service message" do
          allow(Rails.logger).to(receive(:info))
          allow(Maremma).to(receive(:post).and_return(OpenStruct.new(status: 200)))
          expected_log = "[EventImportWorker] #{subj_id} #{relation_type_id} #{obj_id} pushed to the Event Data service."
          expect(Rails.logger).to(receive(:info).with(expected_log))
          EventImportWorker.new.perform(nil, data)
        end
      end

      context "and response is 201" do
        it "logs pushed to event data service message" do
          allow(Rails.logger).to(receive(:info))
          allow(Maremma).to(receive(:post).and_return(OpenStruct.new(status: 201)))
          expected_log = "[EventImportWorker] #{subj_id} #{relation_type_id} #{obj_id} pushed to the Event Data service."
          expect(Rails.logger).to(receive(:info).with(expected_log))
          EventImportWorker.new.perform(nil, data)
        end
      end

      context "when response is 409" do
        it "logs pushed to event data service message" do
          allow(Maremma).to(receive(:post).and_return(OpenStruct.new(status: 409)))
          expected_log = "[EventImportWorker] #{subj_id} #{relation_type_id} #{obj_id} already pushed to the Event Data service."
          expect(Rails.logger).to(receive(:info).with(expected_log))
          EventImportWorker.new.perform(nil, data)
        end
      end

      context "when response body contains a non-empty error object value" do
        it "logs response had an error message" do
          response = OpenStruct.new(
            status: 500,
            body: {
              "errors" => {
                "message" => "foo"
              }
            }
          )

          allow(Rails.logger).to(receive(:error))
          allow(Maremma).to(receive(:post).and_return(response))
          expected_log = "[EventImportWorker] #{subj_id} #{relation_type_id} #{obj_id} had an error"
          expect(Rails.logger).to(receive(:error))
          EventImportWorker.new.perform(nil, data)
        end

        it "logs the error data object" do
          response = OpenStruct.new(
            status: 500,
            body: {
              "errors" => {
                "message" => "foo"
              }
            }
          )

          allow(Rails.logger).to(receive(:error))
          allow(Maremma).to(receive(:post).and_return(response))
          expect(Rails.logger).to(receive(:error).with(data.inspect))
          EventImportWorker.new.perform(nil, data)
        end
      end
    end
  end
end
