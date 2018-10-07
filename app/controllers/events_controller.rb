class EventsController < ApplicationController
  before_action :authenticate_user_from_token!

  def import_crossref
    total = Crossref.import

    render json: { message: "Queued import for #{total} DOIs." }.to_json, status: :ok
  end
end
