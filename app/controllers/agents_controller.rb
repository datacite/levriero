class AgentsController < ApplicationController
  before_action :authenticate_user_from_token!

  def crossref
    authorize! :import, Crossref
    total = Crossref.import

    render json: { message: "[Crossref Agent] Queued import for #{total} DOIs." }.to_json, status: :ok
  end
end
