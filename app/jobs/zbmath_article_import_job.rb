class ZbmathArticleImportJob < ApplicationJob
  queue_as :levriero

  def perform(item, options = {})
    ZbmathArticle.process_zbmath_record(item)
  end
end
