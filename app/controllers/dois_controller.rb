class DoisController < ApplicationController
  def index
    @dois = Doi.where(params)
    render jsonapi: @dois[:data], meta: @dois[:meta]
  end

  def show
    @doi = Doi.where(id: params[:id])
    fail AbstractController::ActionNotFound unless @doi.present?

    render jsonapi: @doi[:data]
  end
end
