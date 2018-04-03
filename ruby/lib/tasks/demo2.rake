module Demo2
  # class ResponseAndCalcRequestWorker
  #   def initialize(group_uuid:,
  #                  num_learners:,
  #                  responses_per_iter:,
  #                  start_date:,
  #                  end_date:)
  #     @group_uuid         = group_uuid
  #     @counter            = 0
  #     @num_learners       = num_learners
  #     @responses_per_iter = responses_per_iter
  #     @start_date         = start_date
  #     @end_date           = end_date

  #     @learner_uuids   = @num_learners.times.map{ SecureRandom.uuid }
  #     @ecosystem_uuids = 10.times.map{ SecureRandom.uuid }
  #   end

  #   def do_work(count:, modulo:, am_boss:)
  #     Rails.logger.level = :info

  #     @counter += 1
  #     Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

  #     start = Time.now

  #     learner_uuids = @responses_per_iter.times.map{ @learner_uuids.sample }

  #     learner_responses = learner_uuids.map{ |learner_uuid|
  #       random_time = Time.at(@start_date + rand * (@end_date.to_f - @start_date.to_f))

  #       LearnerResponse.new(
  #         uuid:           SecureRandom.uuid,
  #         ecosystem_uuid: @ecosystem_uuids.sample,
  #         learner_uuid:   learner_uuid,
  #         question_uuid:  SecureRandom.uuid,
  #         trial_uuid:     SecureRandom.uuid,
  #         was_correct:    [true, false].sample,
  #         responded_at:   random_time,
  #       )
  #     }

  #     LearnerResponse.transaction do
  #       LearnerResponse.import(learner_responses)
  #     end

  #     calc_requests = learner_uuids.uniq.map{ |learner_uuid|
  #       CalcRequest.new(
  #         uuid:               SecureRandom.uuid,
  #         ecosystem_uuid:     @ecosystem_uuids.sample,
  #         learner_uuid:       learner_uuid,
  #         has_been_processed: false,
  #       )
  #     }

  #     CalcRequest.transaction do
  #       CalcRequest.import calc_requests
  #     end

  #     elapsed = Time.now - start
  #     Rails.logger.info "   wrote #{learner_responses.size} + #{calc_requests.size} records in #{'%1.3e' % elapsed} sec"
  #   end

  #   def do_boss(count:, modulo:, protocol:)
  #     Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
  #     # sleep(0.05)
  #   end
  # end

  # class CalcWorker
  #   def initialize(group_uuid:)
  #     @group_uuid = group_uuid
  #     @counter    = 0
  #   end

  #   def do_work(count:, modulo:, am_boss:)
  #     Rails.logger.level = :info

  #     @counter += 1
  #     Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

  #     start = Time.now

  #     num_calc_requests = CalcRequest.transaction do
  #       sql_calc_records_to_process = %Q{
  #         SELECT cr.* FROM calc_requests cr
  #         WHERE cr.has_been_processed = FALSE
  #         ORDER BY cr.created_at ASC
  #         LIMIT 1
  #         FOR UPDATE SKIP LOCKED
  #       }.gsub(/\n\s*/, ' ')

  #       calc_requests = CalcRequest.find_by_sql(sql_calc_records_to_process)

  #       calc_requests.map do |calc_request|
  #         # sleep(0.05)

  #         calc_result = CalcResult.new(
  #           uuid:               SecureRandom.uuid,
  #           calc_request_uuid:  calc_request.uuid,
  #           ecosystem_uuid:     calc_request.ecosystem_uuid,
  #           learner_uuid:       calc_request.learner_uuid,
  #           has_been_reported:  false,
  #         )

  #         calc_request.has_been_processed = true;
  #         calc_request.processed_at       = Time.now;

  #         calc_result.save!
  #         calc_request.save!
  #       end

  #       calc_requests.size
  #     end

  #     elapsed = Time.now - start
  #     Rails.logger.info "   wrote #{num_calc_requests} records in #{'%1.3e' % elapsed} sec"
  #   end

  #   def do_boss(count:, modulo:, protocol:)
  #     Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."

  #     launch_time_sec                = Rails.env.production? ? 120 : 10
  #     min_autoscale_request_interval = launch_time_sec
  #     max_num_workers                = Integer(ENV['AWS_ASG_MAX_SIZE'] || 10)
  #     epsilon                        = 1e-6
  #     rate_average_time              = Rails.env.production? ? 300 : 30

  #     CalcRequest.transaction do
  #       last_autoscale_request = AutoscalingRequest.order(created_at: :desc).first

  #       if last_autoscale_request.nil? or (last_autoscale_request.created_at < Time.now - min_autoscale_request_interval)
  #         arrival_rate = CalcRequest.where("created_at > ?", Time.now - rate_average_time.seconds).count/rate_average_time

  #         backlog_size_requests = [CalcRequest.where(has_been_processed: false).count, 1].max

  #         cur_processing_rate_requests_per_sec = count / 0.25
  #         cur_backlog_burn_time_sec            = backlog_size_requests / [cur_processing_rate_requests_per_sec - arrival_rate, epsilon].max

  #         inc_processing_rate_requests_per_sec = max_num_workers / 0.25
  #         inc_backlog_burn_time_sec            = [cur_backlog_burn_time_sec, launch_time_sec + (backlog_size_requests + (arrival_rate - cur_processing_rate_requests_per_sec)*launch_time_sec) / [inc_processing_rate_requests_per_sec - arrival_rate, epsilon].max].min

  #         dec_processing_rate_requests_per_sec = (count-1) / 0.25
  #         dec_backlog_burn_time_sec            = backlog_size_requests / [dec_processing_rate_requests_per_sec - arrival_rate, epsilon].max

  #         puts "arrival_rate              = #{arrival_rate}"
  #         puts "backlog_size              = #{backlog_size_requests}"
  #         puts "dec_processing_rate       = #{dec_processing_rate_requests_per_sec}"
  #         puts "cur_processing_rate       = #{cur_processing_rate_requests_per_sec}"
  #         puts "inc_processing_rate       = #{inc_processing_rate_requests_per_sec}"
  #         puts "dec_backlog_burn_time_sec = #{dec_backlog_burn_time_sec}"
  #         puts "cur_backlog_burn_time_sec = #{cur_backlog_burn_time_sec}"
  #         puts "inc_backlog_burn_time_sec = #{inc_backlog_burn_time_sec}"

  #         if inc_backlog_burn_time_sec < cur_backlog_burn_time_sec - 10.seconds
  #           AutoscalingRequest.create!(
  #             uuid:         SecureRandom.uuid,
  #             group_uuid:   protocol.group_uuid,
  #             request_type: 'scale_up',
  #           )
  #           scale_up_action
  #         elsif dec_backlog_burn_time_sec < 0.75
  #           AutoscalingRequest.create!(
  #             uuid:         SecureRandom.uuid,
  #             group_uuid:   protocol.group_uuid,
  #             request_type: 'scale_down',
  #           )
  #           scale_down_action
  #         else
  #           do_nothing_action
  #         end
  #       else
  #         puts "recent autoscaling event prevents further adjustments"
  #       end
  #     end
  #   end

  #   def scale_up_action
  #     puts "   SCALE UP"
  #     if Rails.env.production?
  #       system('/bin/bash /home/ubuntu/primary_repo/services/scale_up.sh')
  #     end
  #   end

  #   def scale_down_action
  #     puts "   SCALE DOWN"
  #     if Rails.env.production?
  #       system('/bin/bash /home/ubuntu/primary_repo/services/scale_down.sh')
  #     end
  #   end

  #   def do_nothing_action
  #     puts "   DO NOTHING"
  #   end
  # end

  # class ReportWorker
  #   def initialize(group_uuid:)
  #     @group_uuid = group_uuid
  #     @counter    = 0
  #   end

  #   def do_work(count:, modulo:, am_boss:)
  #     Rails.logger.level = :info

  #     @counter += 1
  #     Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

  #     start = Time.now

  #     calc_results = CalcResult.transaction do
  #       sql_calc_results_to_process = %Q{
  #         SELECT cr.* FROM calc_results cr
  #         WHERE cr.has_been_reported = FALSE
  #         AND   cr.partition_value % #{count} = #{modulo}
  #         ORDER BY cr.created_at ASC
  #         LIMIT 100
  #         FOR UPDATE SKIP LOCKED
  #       }.gsub(/\n\s*/, ' ')

  #       calc_results = CalcResult.find_by_sql(sql_calc_results_to_process)

  #       calc_results.each do |calc_result|
  #         calc_result.has_been_reported = true
  #         calc_result.reported_at       = Time.now
  #         calc_result.save!
  #       end

  #       calc_results
  #     end

  #     elapsed = Time.now - start
  #     Rails.logger.info "   wrote #{calc_results.size} records in #{'%1.3e' % elapsed} sec"
  #   end

  #   def do_boss(count:, modulo:, protocol:)
  #     Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."
  #     # sleep(0.05)
  #   end
  # end

  class MonitorWorker
    def initialize(group_uuid:)
      @group_uuid = group_uuid
      @counter    = 0
    end

    def do_work(count:, modulo:, am_boss:)
      Rails.logger.level = :info

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      is_healthy = false

      request_records = RequestRecord.where(aws_instance_id: ENV['AWS_INSTANCE_ID'])
                                     .where('created_at > ?', Time.now.utc - 1.second)
                                     .where('request_elapsed < ?', 0.5)

      if request_records.any?
        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} request records exist"
        is_healthy = true
      else
        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} curling"

        curl_successful = false
        easy = Curl::Easy.new("http://localhost:3000/ping") do |curl|
          curl.connect_timeout_ms   = 1000
          curl.timeout_ms           = 1000
          curl.on_success do |easy|
            curl_successful = true
          end
        end

        begin
          easy.perform
        rescue
        end

        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} curl_successful = #{curl_successful}"

        request_records = RequestRecord.where(aws_instance_id: ENV['AWS_INSTANCE_ID'])
                                       .where('created_at > ?', Time.now.utc - 1.second)
                                       .where('request_elapsed < ?', 0.5)

        is_healthy = request_records.any?

        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} num records = #{request_records.count} is_healthy = #{is_healthy}"
      end

      if is_healthy
        puts "   healthy"
        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} healthy"
        if Rails.env.production?
          system('/bin/bash /home/ubuntu/primary_repo/services/status_healthy.sh')
        end
      else
        puts "   UNHEALTHY"
        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}] #{am_boss ? '*' : ' '} UNHEALTHY"
        if Rails.env.production?
          system('/bin/bash /home/ubuntu/primary_repo/services/status_unhealthy.sh')
        end
      end

      elapsed = Time.now - start
      Rails.logger.info "   wrote 0 records in #{'%1.3e' % elapsed} sec"
    end

    def do_boss(count:, modulo:, protocol:)
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{@group_uuid}:[#{modulo}/#{count}]   doing boss stuff..."

      start = Time.now

      asg_num_handled_requests = RequestRecord.where(aws_asg_name: ENV['AWS_ASG_NAME'])
                                              .where('created_at > ?', Time.now.utc - 10.seconds)
                                              .count

      client = Aws::AutoScaling::Client.new

      asg = client.describe_auto_scaling_groups(
        auto_scaling_group_names: [ ENV['AWS_ASG_NAME'] ]
      ).auto_scaling_groups[0]

      asg_requests_per_sec_per_instance     = 10.0
      asg_reserve_requests_per_sec          = 20.0
      asg_demand_requests_per_sec           = asg_num_handled_requests / 10.0
      asg_current_capacity_requests_per_sec = asg.desired_capacity * asg_requests_per_sec_per_instance
      asg_desired_instances                 = ((asg_demand_requests_per_sec + asg_reserve_requests_per_sec)/asg_requests_per_sec_per_instance).ceil

      Rails.logger.info "ASG -------------------------------------------------"
      Rails.logger.info "ASG asg_requests_per_sec_per_instance     = #{asg_requests_per_sec_per_instance}"
      Rails.logger.info "ASG asg_reserve_requests_per_sec          = #{asg_reserve_requests_per_sec}"
      Rails.logger.info "ASG asg_demand_requests_per_sec           = #{asg_demand_requests_per_sec}"
      Rails.logger.info "ASG asg_current_capacity_requests_per_sec = #{asg_current_capacity_requests_per_sec}"
      Rails.logger.info "ASG asg_desired_instances                 = #{asg_desired_instances}"
      Rails.logger.info "ASG current desired_capacity              = #{asg.desired_capacity}"

      if asg.desired_capacity != asg_desired_instances
        AutoscalingRequest.create!(
          uuid:         SecureRandom.uuid.to_s,
          group_uuid:   @group_uuid,
          request_type: (asg_desired_instances > asg.desired_capacity) ? 'increase' : 'decrease',
        )

        client.set_desired_capacity({
          auto_scaling_group_name: ENV['AWS_ASG_NAME'],
          desired_capacity:        asg_desired_instances,
          honor_cooldown:          false,
        })
      end

      elapsed = Time.now - start
      Rails.logger.info "   wrote 0 records in #{'%1.3e' % elapsed} sec"
    end
  end
end

# namespace :demo2 do
#   desc "Create LearnerResponses and CalcRequests"
#   task :request, [:group_uuid, :work_interval, :timing_modulo, :timing_offset] => :environment do |t, args|
#     group_uuid    = args[:group_uuid]
#     work_interval = (args[:work_interval] || '1.0').to_f.seconds
#     boss_interval = Rails.env.production? ? 30.seconds : 5.seconds
#     timing_modulo = (args[:timing_modulo]   || '1.0').to_f.seconds
#     timing_offset = (args[:timing_offset]   || '0.0').to_f.seconds

#     start_date = Chronic.parse('2017-01-01 12:00')
#     end_date   = Chronic.parse('2017-12-01 12:00')

#     worker = Demo2::ResponseAndCalcRequestWorker.new(
#       group_uuid:         group_uuid,
#       num_learners:       1000,
#       responses_per_iter: 1,
#       start_date:         start_date,
#       end_date:           end_date,
#     )

#     protocol = Protocol.new(
#       min_work_interval:  work_interval,
#       work_block:         lambda { |protocol:|
#                             worker.do_work(count: protocol.count, modulo: protocol.modulo, am_boss: protocol.am_boss?)
#                           },
#       min_boss_interval:  boss_interval,
#       boss_block:         lambda { |protocol:|
#                             worker.do_boss(count: protocol.count, modulo: protocol.modulo, protocol: protocol)
#                           },
#       group_uuid:         group_uuid,
#       instance_uuid:      SecureRandom.uuid.to_s,
#       instance_desc:      ENV['AWS_INSTANCE_ID'],
#       dead_record_timeout: 5.seconds,
#       reference_time:     Chronic.parse('Jan 1, 2000 12:00:00pm'),
#       timing_modulo:      timing_modulo,
#       timing_offset:      timing_offset,
#     )

#     protocol.run
#   end
# end

# namespace :demo2 do
#   desc "Process CalcRequests"
#   task :calc, [:group_uuid, :work_interval, :work_modulo, :work_offset] => :environment do |t, args|
#     group_uuid    = args[:group_uuid]
#     work_interval = (args[:work_interval] || '1.0').to_f.seconds
#     boss_interval = Rails.env.production? ? 30.seconds : 5.seconds
#     work_modulo   = (args[:work_modulo]   || '1.0').to_f.seconds
#     work_offset   = (args[:work_offset]   || '0.0').to_f.seconds

#     worker = Demo2::CalcWorker.new(
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
#       boss_block: lambda { |instance_count:, instance_modulo:, protocol:|
#                     worker.do_boss(count: instance_count, modulo: instance_modulo, protocol: protocol)
#                   }
#     )

#     protocol.run
#   end
# end

# namespace :demo2 do
#   desc "Report CalcResults"
#   task :report, [:group_uuid, :work_interval, :work_modulo, :work_offset] => :environment do |t, args|
#     group_uuid    = args[:group_uuid]
#     work_interval = (args[:work_interval] || '1.0').to_f.seconds
#     boss_interval = Rails.env.production? ? 30.seconds : 5.seconds
#     work_modulo   = (args[:work_modulo]   || '1.0').to_f.seconds
#     work_offset   = (args[:work_offset]   || '0.0').to_f.seconds

#     worker = Demo2::ReportWorker.new(
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
#       boss_block: lambda { |instance_count:, instance_modulo:, protocol:|
#                     worker.do_boss(count: instance_count, modulo: instance_modulo, protocol: protocol)
#                   }
#     )

#     protocol.run
#   end
# end

namespace :demo2 do
  desc "Monitor"
  task :monitor, [:group_uuid, :work_interval, :timing_modulo, :timing_offset] => :environment do |t, args|
    group_uuid    = args[:group_uuid]
    work_interval = (args[:work_interval] || '5.0').to_f.seconds
    boss_interval = Rails.env.production? ? 10.seconds : 10.seconds
    timing_modulo = (args[:timing_modulo]   || '5.0').to_f.seconds
    timing_offset = (args[:timing_offset]   || '0.0').to_f.seconds

    worker = Demo2::MonitorWorker.new(
      group_uuid: group_uuid,
    )

    protocol = Protocol.new(
      min_work_interval:  work_interval,
      work_block:         lambda { |protocol:|
                            worker.do_work(count: protocol.count, modulo: protocol.modulo, am_boss: protocol.am_boss?)
                          },
      min_boss_interval:  boss_interval,
      boss_block:         lambda { |protocol:|
                            worker.do_boss(count: protocol.count, modulo: protocol.modulo, protocol: protocol)
                          },
      group_uuid:         group_uuid,
      instance_uuid:      SecureRandom.uuid.to_s,
      instance_desc:      ENV['AWS_INSTANCE_ID'],
      dead_record_timeout: 5.seconds,
      reference_time:     Chronic.parse('Jan 1, 2000 12:00:00pm'),
      timing_modulo:      timing_modulo,
      timing_offset:      timing_offset,
    )

    protocol.run
  end
end