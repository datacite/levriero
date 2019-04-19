module Levriero
  class Application
    g = Git.open(Rails.root)
    VERSION = g.tags.map { |t| Gem::Version.new(t.name) }.sort.last.to_s
    REVISION = g.object('HEAD').sha
  end
end