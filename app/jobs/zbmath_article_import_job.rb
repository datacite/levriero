class ZbmathArticleImportJob < ApplicationJob
  queue_as :levriero

  def perform(item, options = {})
    ZbmathArticle.parse_zbmath_record(item, options)
  end
end
