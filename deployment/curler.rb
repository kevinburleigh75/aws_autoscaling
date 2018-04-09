#!/usr/bin/env ruby

require 'curb'
require 'time'
require 'thread'

semaphore = Mutex.new

elb_url             = ARGV[0]
min_sec_per_request = Float(ARGV[1])
num_threads         = Integer(ARGV[2] || 1)
delay_thresh        = Float(ARGV[3]   || 0.2)
delay_error_thresh  = Float(ARGV[4]   || 3.0)
puts min_sec_per_request

error_counter       = 0
delay_counter       = 0
delay_error_counter = 0
success_counter     = 0
call_counter        = 0

threads = num_threads.times.map do
  thread = Thread.new {
    sleep(Kernel.rand)

    thread_success_counter = 0
    success = false

    easy = Curl::Easy.new("http://#{elb_url}:3000/task1") do |curl|
      curl.connect_timeout_ms   = 1000
      curl.timeout_ms           = 1000
      curl.on_success do |easy|
        success = true
      end
    end

    while true do
      start = Time.now

      success = false

      begin
        easy.perform
      rescue
      end

      semaphore.synchronize {
        call_counter += 1
      }

      if success
        semaphore.synchronize {
          success_counter += 1
        }

        thread_success_counter += 1
      else
        semaphore.synchronize {
          error_counter += 1
        }
      end

      elapsed = Time.now - start

      if success and (thread_success_counter > 1) and (elapsed > delay_thresh)
        semaphore.synchronize {
          delay_counter += 1
        }
      end

      if success and (thread_success_counter > 1) and (elapsed > delay_error_thresh)
        semaphore.synchronize {
          delay_error_counter += 1
        }
      end

      semaphore.synchronize {
        puts "#{Time.now.utc.iso8601(6)} T:#{Thread.current.object_id} C:#{call_counter} S:#{success_counter} E:#{error_counter} DE:#{delay_error_counter} D:#{delay_counter} #{'%1.3e' % elapsed} #{easy.body_str}"
      }

      sleep([start + min_sec_per_request - Time.now, 0].max)
    end
  }

  thread
end

threads.each{|thr| thr.join}

