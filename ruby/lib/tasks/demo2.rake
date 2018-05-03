module Demo2
  class FakeClient
    def initialize(protocol:)
      @protocol = protocol
    end

    def set_instance_health(instance_id:, health_status:)
      puts "setting health of #{instance_id} to #{health_status}"
    end

    def describe_auto_scaling_groups(auto_scaling_group_names:)
      return self
    end

    def auto_scaling_groups
      return [self]
    end

    def desired_capacity
      return @protocol.count
    end

    def set_desired_capacity(auto_scaling_group_name:, desired_capacity:, honor_cooldown:)
      puts "setting desired_capacity of #{auto_scaling_group_name} to #{desired_capacity}"
    end

    def tags
      return []
    end
  end

  class MonitorWorker
    def initialize(group_uuid:, group_desc:, instance_id:, asg_name:)
      @group_uuid  = group_uuid
      @group_desc  = group_desc
      @instance_id = instance_id
      @asg_name    = asg_name

      @counter = 0
    end

    def do_work(protocol:)
      Rails.logger.level = :info

      @counter += 1
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} #{@counter % 10} working away as usual..."

      start = Time.now

      is_healthy = false

      request_records = RequestRecord.where(aws_instance_id: @instance_id)
                                     .where('created_at > ?', Time.now.utc - 1.second)
                                     .where('request_elapsed < ?', 0.5)

      if request_records.any?
        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} request records exist"
        is_healthy = true
      else
        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} curling"

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

        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} curl_successful = #{curl_successful}"

        request_records = RequestRecord.where(aws_instance_id: @instance_id)
                                       .where('created_at > ?', Time.now.utc - 1.second)
                                       .where('request_elapsed < ?', 0.5)

        is_healthy = request_records.any?

        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} num records = #{request_records.count} is_healthy = #{is_healthy}"
      end

      client =
        if Rails.env.production?
          Aws::AutoScaling::Client.new
        else
          FakeClient.new(protocol: protocol)
        end

      if is_healthy
        # puts "   healthy"

        HealthCheckEvent.create!(
          health_check_uuid: SecureRandom.uuid.to_s,
          instance_id:       @instance_id,
          health_status:     'healthy',
        )

        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} healthy"

        client.set_instance_health(
          instance_id: @instance_id,
          health_status: 'Healthy',
        )
      else
        # puts "   UNHEALTHY"

        HealthCheckEvent.create!(
          health_check_uuid: SecureRandom.uuid.to_s,
          instance_id:       @instance_id,
          health_status:     'unhealthy',
        )

        Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}] #{protocol.am_boss? ? '*' : ' '} UNHEALTHY"

        client.set_instance_health(
          instance_id: @instance_id,
          health_status: 'Unhealthy',
        )
      end

      elapsed = Time.now - start
      Rails.logger.info "   wrote 0 records in #{'%1.3e' % elapsed} sec"
    end

    def do_boss(protocol:)
      Rails.logger.info "#{Time.now.utc.iso8601(6)} #{Process.pid} #{protocol.group_uuid}:[#{protocol.modulo}/#{protocol.count}]   doing boss stuff..."

      start = Time.now

      asg_num_handled_requests = RequestRecord.where(aws_asg_name: @asg_name)
                                              .where('created_at > ?', Time.now.utc - 10.seconds)
                                              .count

      client =
        if Rails.env.production?
          Aws::AutoScaling::Client.new
        else
          FakeClient.new(protocol: protocol)
        end

      asg = client.describe_auto_scaling_groups(
        auto_scaling_group_names: [ @asg_name ]
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

      unless asg.tags.detect{|tag| tag.key == 'FreezeAutoscalingEvents'}
        if asg.desired_capacity < asg_desired_instances
          AutoscalingRequest.create!(
            uuid:             SecureRandom.uuid.to_s,
            group_uuid:       @group_uuid,
            request_type:     'increase',
            desired_capacity: asg_desired_instances,
          )

          client.set_desired_capacity({
            auto_scaling_group_name: @asg_name,
            desired_capacity:        asg_desired_instances,
            honor_cooldown:          false,
          })
        elsif asg.desired_capacity > asg_desired_instances
          num_recent_increases = AutoscalingRequest.where(group_uuid: @group_uuid)
                                                   .where('created_at > ?', Time.now.utc - 5.minutes)
                                                   .where(request_type: 'increase')
                                                   .count

          if num_recent_increases == 0
            AutoscalingRequest.create!(
              uuid:             SecureRandom.uuid.to_s,
              group_uuid:       @group_uuid,
              request_type:     'decrease',
              desired_capacity: asg_desired_instances,
            )

            client.set_desired_capacity({
              auto_scaling_group_name: @asg_name,
              desired_capacity:        asg_desired_instances,
              honor_cooldown:          false,
            })
          end
        end
      end

      elapsed = Time.now - start
      Rails.logger.info "   wrote 0 records in #{'%1.3e' % elapsed} sec"
    end
  end
end

namespace :demo2 do
  desc "Monitor"
  task :monitor, [:group_uuid, :work_interval, :timing_modulo, :timing_offset] => :environment do |t, args|
    group_uuid    = args[:group_uuid]
    work_interval = (args[:work_interval]   || '5.0').to_f.seconds
    timing_modulo = (args[:timing_modulo]   || '5.0').to_f.seconds
    timing_offset = (args[:timing_offset]   || '0.0').to_f.seconds

    reference_time = Chronic.parse('Jan 1, 2000 12:00:00pm')

    if Rails.env.production?
      boss_interval = 10.seconds
      group_desc    = ENV.fetch('AWS_ASG_SHORT_NAME')
      instance_id   = ENV.fetch('AWS_INSTANCE_ID')
      instance_desc = ENV.fetch('AWS_INSTANCE_ID')
      asg_name      = ENV.fetch('AWS_ASG_NAME')
    else
      boss_interval = 10.seconds
      group_desc    = 'some group desc'
      instance_id   = ApplicationController.fake_aws_instance_id
      instance_desc = "desc for #{Process.pid}"
      asg_name      = ApplicationController.fake_asg_name
    end

    worker = Demo2::MonitorWorker.new(
      group_uuid:  group_uuid,
      group_desc:  group_desc,
      instance_id: instance_id,
      asg_name:    asg_name,
    )

    protocol = Protocol.new(
      min_work_interval:  work_interval,
      work_block:         lambda { |protocol:|
                            worker.do_work(protocol: protocol)
                          },
      min_boss_interval:  boss_interval,
      boss_block:         lambda { |protocol:|
                            worker.do_boss(protocol: protocol)
                          },
      group_uuid:         group_uuid,
      group_desc:         group_desc,
      instance_uuid:      SecureRandom.uuid.to_s,
      instance_desc:      instance_desc,
      dead_record_timeout: 5.seconds,
      reference_time:     reference_time,
      timing_modulo:      timing_modulo,
      timing_offset:      timing_offset,
    )

    protocol.run
  end
end