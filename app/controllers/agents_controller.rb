class AgentsController < ApplicationController
  before_action :authenticate_user_from_token!

  def crossref
    authorize! :import, Crossref
    total = Crossref.import

    render json: { message: "[Crossref Agent] Queued import for #{total} DOIs." }.to_json, status: :ok
  end

  def crossref_orcid
    authorize! :import, CrossrefOrcid
    total = CrossrefOrcid.import

    render json: { message: "[Crossref-ORCID Agent] Queued import for #{total} DOIs." }.to_json, status: :ok
  end

  def crossref_funder
    authorize! :import, CrossrefFunder
    total = CrossrefFunder.import

    render json: { message: "[Crossref-Funder Agent] Queued import for #{total} DOIs." }.to_json, status: :ok
  end

  def crossref_related
    authorize! :import, CrossrefRelated
    total = CrossrefRelated.import

    render json: { message: "[Crossref-Related Agent] Queued import for #{total} DOIs." }.to_json, status: :ok
  end

  def crossref_import
    authorize! :import, CrossrefImport
    total = CrossrefImport.import

    render json: { message: "[Crossref-Import Agent] Queued import for #{total} DOIs." }.to_json, status: :ok
  end
end
