class ZbmathArticleImportByMonthJob < ApplicationJob
  queue_as :levriero

  def perform(options = {})
    ZbmathArticle.import(options)
  end
end
