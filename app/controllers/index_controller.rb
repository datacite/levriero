class IndexController < ApplicationController
  def index
    render plain: ENV["SITE_TITLE"]
  end

  def show
    id = params[:id]
    foo = Rails.cache.fetch("wendel/#{id}", expires_in: 1.day) { "cached_wendel_#{id}_test" }
    render json: {message: foo}
  end
end
