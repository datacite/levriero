# require 'rails_helper'

# describe Doi, type: :model, vcr: true do
#   # it { should validate_presence_of(:doi) }

#   describe "state" do
#     subject { FactoryBot.create(:doi) }

#     describe "new" do
#       it "defaults to new" do
#         pending("something else getting finished")
#         expect(subject).to have_state(:new)
#       end
#     end

#     describe "registered" do
#       it "can register" do
#         pending("something else getting finished")
#         subject.register
#         expect(subject).to have_state(:registered)
#       end

#       it "can't register with test prefix" do
#         pending("something else getting finished")
#         subject = FactoryBot.create(:doi, doi: "10.5072/x")
#         subject.register
#         expect(subject).to have_state(:draft)
#       end
#     end

#     describe "findable" do
#       it "can publish" do
#         pending("something else getting finished")
#         subject.publish
#         expect(subject).to have_state(:findable)
#       end

#       it "can't register with test prefix" do
#         pending("something else getting finished")
#         subject = FactoryBot.create(:doi, doi: "10.5072/x")
#         subject.publish
#         expect(subject).to have_state(:draft)
#       end
#     end

#     describe "flagged" do
#       it "can flag" do
#         pending("something else getting finished")
#         subject.register
#         subject.flag
#         expect(subject).to have_state(:flagged)
#       end

#       it "can't flag if draft" do
#         pending("something else getting finished")
#         subject.flag
#         expect(subject).to have_state(:draft)
#       end
#     end

#     describe "broken" do
#       it "can link_check" do
#         pending("something else getting finished")
#         subject.register
#         subject.link_check
#         expect(subject).to have_state(:broken)
#       end

#       it "can't link_check if draft" do
#         pending("something else getting finished")
#         subject.link_check
#         expect(subject).to have_state(:draft)
#       end
#     end
#   end
# end
