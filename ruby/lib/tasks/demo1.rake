# module Demo1
#   class ResponseAndCalcRequestWorker
#     def initialize(group_uuid:,
#                    num_learners:,
#                    responses_per_iter:,
#                    start_date:,
#                    end_date:)
#       @group_uuid         = group_uuid
#       @counter            = 0
#       @num_learners       = num_learners
#       @responses_per_iter = responses_per_iter
#       @start_date         = start_date
#       @end_date           = end_date

#       @learner_uuids   = @num_learners.times.map{ SecureRandom.uuid }
#       @ecosystem_uuids = 10.times.map{ SecureRandom.uuid }
#     end

#     def do_work(count:, modulo:, am_boss:)
#       Rails.logger.level = :info

#       @counter += 1
#       Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

#       start = Time.now

#       learner_uuids = @responses_per_iter.times.map{ @learner_uuids.sample }

#       learner_responses = learner_uuids.map{ |learner_uuid|
#         random_time = Time.at(@start_date + rand * (@end_date.to_f - @start_date.to_f))

#         LearnerResponse.new(
#           uuid:           SecureRandom.uuid,
#           ecosystem_uuid: @ecosystem_uuids.sample,
#           learner_uuid:   learner_uuid,
#           question_uuid:  SecureRandom.uuid,
#           trial_uuid:     SecureRandom.uuid,
#           was_correct:    [true, false].sample,
#           responded_at:   random_time,
#         )
#       }

#       LearnerResponse.transaction do
#         LearnerResponse.import(learner_responses)
#       end

#       calc_requests = learner_uuids.uniq.map{ |learner_uuid|
#         CalcRequest.new(
#           uuid:               SecureRandom.uuid,
#           ecosystem_uuid:     @ecosystem_uuids.sample,
#           learner_uuid:       learner_uuid,
#           has_been_processed: false,
#         )
#       }

#       CalcRequest.transaction do
#         CalcRequest.import calc_requests
#       end

#       elapsed = Time.now - start
#       Rails.logger.info "   wrote #{learner_responses.size} + #{calc_requests.size} records in #{'%1.3e' % elapsed} sec"
#     end

#     def do_boss(count:, modulo:, min_work_interval:)
#       Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
#       # sleep(0.05)
#     end
#   end

#   class CalcWorker
#     def initialize(group_uuid:)
#       @group_uuid = group_uuid
#       @counter    = 0
#     end

#     def do_work(count:, modulo:, am_boss:)
#       Rails.logger.level = :info

#       @counter += 1
#       Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

#       start = Time.now

#       num_calc_requests = CalcRequest.transaction do
#         sql_calc_records_to_process = %Q{
#           SELECT cr.* FROM calc_requests cr
#           WHERE cr.has_been_processed = FALSE
#           AND   cr.partition_value % #{count} = #{modulo}
#           ORDER BY cr.created_at ASC
#           LIMIT 1
#           FOR UPDATE SKIP LOCKED
#         }.gsub(/\n\s*/, ' ')

#         calc_requests = CalcRequest.find_by_sql(sql_calc_records_to_process)

#         calc_requests.map do |calc_request|
#           # sleep(0.05)

#           calc_result = CalcResult.new(
#             uuid:               SecureRandom.uuid,
#             calc_request_uuid:  calc_request.uuid,
#             ecosystem_uuid:     calc_request.ecosystem_uuid,
#             learner_uuid:       calc_request.learner_uuid,
#             has_been_reported:  false,
#           )

#           calc_request.has_been_processed = true;
#           calc_request.processed_at       = Time.now;

#           calc_result.save!
#           calc_request.save!
#         end

#         calc_requests.size
#       end

#       elapsed = Time.now - start
#       Rails.logger.info "   wrote #{num_calc_requests} records in #{'%1.3e' % elapsed} sec"
#     end

#     def do_boss(count:, modulo:, min_work_interval:)
#       Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
#       # sleep(0.05)
#     end
#   end

#   class ReportWorker
#     def initialize(group_uuid:)
#       @group_uuid = group_uuid
#       @counter    = 0
#     end

#     def do_work(count:, modulo:, am_boss:)
#       Rails.logger.level = :info

#       @counter += 1
#       Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

#       start = Time.now

#       calc_results_size = CalcResult.transaction do
#         sql_calc_results_to_process = %Q{
#           SELECT cr.* FROM calc_results cr
#           WHERE cr.has_been_reported = FALSE
#           AND   cr.partition_value % #{count} = #{modulo}
#           ORDER BY cr.created_at ASC
#           LIMIT 100
#           FOR UPDATE SKIP LOCKED
#         }.gsub(/\n\s*/, ' ')

#         calc_results = CalcResult.find_by_sql(sql_calc_results_to_process)

#         calc_results.each do |calc_request|
#           calc_request.has_been_reported = true
#           calc_request.reported_at       = Time.now
#           calc_request.save!
#         end

#         calc_results.size
#       end

#       elapsed = Time.now - start
#       Rails.logger.info "   wrote #{calc_results_size} records in #{'%1.3e' % elapsed} sec"
#     end

#     def do_boss(count:, modulo:, min_work_interval:)
#       Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
#       # sleep(0.05)
#     end
#   end
# end

# namespace :demo1 do
#   desc "Create LearnerResponses and CalcRequests"
#   task :request, [:group_uuid, :work_interval, :work_modulo, :work_offset] => :environment do |t, args|
#     group_uuid    = args[:group_uuid]
#     work_interval = (args[:work_interval] || '1.0').to_f.seconds
#     boss_interval = 5.seconds
#     work_modulo   = (args[:work_modulo]   || '1.0').to_f.seconds
#     work_offset   = (args[:work_offset]   || '0.0').to_f.seconds

#     start_date = Chronic.parse('2017-01-01 12:00')
#     end_date   = Chronic.parse('2017-12-01 12:00')

#     worker = Demo1::ResponseAndCalcRequestWorker.new(
#       group_uuid:         group_uuid,
#       num_learners:       1000,
#       responses_per_iter: 1,
#       start_date:         start_date,
#       end_date:           end_date,
#     )

#     protocol = Protocol.new(
#       min_work_interval:  work_interval,
#       min_boss_interval:  boss_interval,
#       work_modulo:        work_modulo,
#       work_offset:        work_offset,
#       group_uuid:         group_uuid,
#       work_block: lambda { |instance_count:, instance_modulo:, am_boss:|
#                     worker.do_work(count: instance_count, modulo: instance_modulo, am_boss: am_boss)
#                   },
#       boss_block: lambda { |instance_count:, instance_modulo:, min_work_interval:|
#                     worker.do_boss(count: instance_count, modulo: instance_modulo, min_work_interval: min_work_interval)
#                   }
#     )

#     protocol.run
#   end
# end

# namespace :demo1 do
#   desc "Process CalcRequests"
#   task :calc, [:group_uuid, :work_interval, :work_modulo, :work_offset] => :environment do |t, args|
#     group_uuid    = args[:group_uuid]
#     work_interval = (args[:work_interval] || '1.0').to_f.seconds
#     boss_interval = 5.seconds
#     work_modulo   = (args[:work_modulo]   || '1.0').to_f.seconds
#     work_offset   = (args[:work_offset]   || '0.0').to_f.seconds

#     worker = Demo1::CalcWorker.new(
#       group_uuid: group_uuid,
#     )

#     protocol = Protocol.new(
#       min_work_interval:  work_interval,
#       min_boss_interval:  boss_interval,
#       work_modulo:        work_modulo,
#       work_offset:        work_offset,
#       group_uuid:         group_uuid,
#       work_block: lambda { |instance_count:, instance_modulo:, am_boss:|
#                     worker.do_work(count: instance_count, modulo: instance_modulo, am_boss: am_boss)
#                   },
#       boss_block: lambda { |instance_count:, instance_modulo:, min_work_interval:|
#                     worker.do_boss(count: instance_count, modulo: instance_modulo, min_work_interval: min_work_interval)
#                   }
#     )

#     protocol.run
#   end
# end

# namespace :demo1 do
#   desc "Report CalcResults"
#   task :report, [:group_uuid, :work_interval, :work_modulo, :work_offset] => :environment do |t, args|
#     group_uuid    = args[:group_uuid]
#     work_interval = (args[:work_interval] || '1.0').to_f.seconds
#     boss_interval = 5.seconds
#     work_modulo   = (args[:work_modulo]   || '1.0').to_f.seconds
#     work_offset   = (args[:work_offset]   || '0.0').to_f.seconds

#     worker = Demo1::ReportWorker.new(
#       group_uuid: group_uuid,
#     )

#     protocol = Protocol.new(
#       min_work_interval:  work_interval,
#       min_boss_interval:  boss_interval,
#       work_modulo:        work_modulo,
#       work_offset:        work_offset,
#       group_uuid:         group_uuid,
#       work_block: lambda { |instance_count:, instance_modulo:, am_boss:|
#                     worker.do_work(count: instance_count, modulo: instance_modulo, am_boss: am_boss)
#                   },
#       boss_block: lambda { |instance_count:, instance_modulo:, min_work_interval:|
#                     worker.do_boss(count: instance_count, modulo: instance_modulo, min_work_interval: min_work_interval)
#                   }
#     )

#     protocol.run
#   end
# end
