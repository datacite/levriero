module Levriero
  class Application
    begin
      g = Git.open(Rails.root)
      VERSION = g.tags.map { |t| Gem::Version.new(t.name) }.max.to_s
      REVISION = g.object("HEAD").sha
    rescue ArgumentError
      VERSION = "0.0.0"
      REVISION = "unknown"
    end
  end
end
