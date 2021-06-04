class ImportJob < ApplicationJob
  queue_as :levriero

  def perform(data)
    klass = Kernel.const_get(data.fetch("type").chomp("s").capitalize)
    klass.import_record(data)
  end
end
