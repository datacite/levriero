# class EventDeleteWorker
#   include Shoryuken::Worker

#   shoryuken_options queue: ->{ "#{ENV['RAILS_ENV']}_event" }

#   def perform(data)
#     klass = Kernel.const_get(data.fetch("type").chomp('s').capitalize)
#     record = klass.find_by_id(data.fetch("id"))
#     record.delete_record if record.present?
#     record
#   end
# end
