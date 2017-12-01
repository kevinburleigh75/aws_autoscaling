# namespace :responses do
#   desc "Query request records"
#   task :query, [:start_date, :end_date, :partition_count, :partition_modulo, :max_requests] => :environment do |t, args|
#     start_date       = Chronic.parse(args[:start_date])
#     end_date         = Chronic.parse(args[:end_date])
#     partition_count  = Integer(args[:partition_count])
#     partition_modulo = Integer(args[:partition_modulo])
#     max_requests     = Integer(args[:max_requests])

#     puts "start = #{start_date}"
#     puts "end   = #{end_date}"
#     puts "c:m   = #{partition_count}:#{partition_modulo}"

#     RequestRecord.connection

#     start = Time.now

#     sql = %Q{
#       SELECT * FROM request_records as req
#       WHERE req.has_been_processed = FALSE
#       AND   req.partition_value % #{partition_count} = #{partition_modulo}
#       ORDER BY req.created_at ASC
#       LIMIT #{max_requests}
#     }.gsub(/\n\s*/, ' ')

#     requests = RequestRecord.find_by_sql(sql);
#     elapsed = Time.now - start

#     puts "count = #{requests.size}"
#     if requests.size > 0
#       puts requests.first.inspect
#     end
#     puts "elapsed = #{elapsed}"
#     # requests.each{|req| puts req.inspect}
#   end

#   desc "Create response records"
#   task :create, [:start_date, :end_date, :partition_count, :partition_modulo, :max_requests] => :environment do |t, args|
#     start_date       = Chronic.parse(args[:start_date])
#     end_date         = Chronic.parse(args[:end_date])
#     partition_count  = Integer(args[:partition_count])
#     partition_modulo = Integer(args[:partition_modulo])
#     max_requests     = Integer(args[:max_requests])

#     puts "start = #{start_date}"
#     puts "end   = #{end_date}"

#     sql = %Q{
#       SELECT * FROM request_records as req
#       WHERE req.has_been_processed = FALSE
#       AND   req.partition_value % #{partition_count} = #{partition_modulo}
#       ORDER BY req.created_at ASC
#       LIMIT #{max_requests}
#     }.gsub(/\n\s*/, ' ')

#     ResponseRecord.connection
#     start = Time.now

#     requests = RequestRecord.find_by_sql(sql);
#     puts "query elapsed = #{Time.now - start}"
#     puts "count         = #{requests.size}"
#     if requests.size > 0
#       puts requests.first.inspect
#     end
#     # requests.each{|req| puts req.inspect}

#     ResponseRecord.transaction(isolation: :repeatable_read) do
#       requests.map do |request|
#         ResponseRecord.create!(uuid: request.uuid)
#         request.has_been_processed = true
#         request.save!
#       end
#     end

#     elapsed = Time.now - start;
#     puts "elapsed = #{elapsed}"
#   end

# end