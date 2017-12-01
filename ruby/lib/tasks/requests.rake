# require 'securerandom'

# namespace :requests do
#   desc "Create request records"
#   task :create, [:start_date,:end_date,:num_requests] => :environment do |t, args|
#     start_date   = Chronic.parse(args[:start_date])
#     end_date     = Chronic.parse(args[:end_date])
#     num_requests = Integer(args[:num_requests])

#     ResponseRecord.connection

#     RequestRecord.transaction(isolation: :repeatable_read) do
#       puts "#{Time.now} times..."
#       request_times = num_requests.times.map{
#         random_times = Time.at(start_date + rand * (end_date.to_f - start_date.to_f))
#       }
#       puts "#{Time.now} records..."
#       request_records = request_times.map{ |req_time|
#         RequestRecord.new(
#           uuid:               SecureRandom.uuid,
#           partition_value:    Kernel.rand(1*2*3*4*5*6*7*8*9*10),
#           has_been_processed: false,
#           created_at:         req_time,
#         )
#       }
#       puts "#{Time.now} import..."
#       RequestRecord.import(request_records)
#       puts "#{Time.now} done..."
#     end

#   end
# end
