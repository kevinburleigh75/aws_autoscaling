#!/usr/bin/env ruby

counter = 0
File::open('/home/ubuntu/log1.txt', 'a') do |fh|
  fh.write("#{Time.now} #{ENV['ASG_DB_ENDPOINT']}\n")
  fh.write("#{Time.now} #{ENV['ASG_DB_PORT']}\n")
  fh.write("#{Time.now} #{ENV['ASG_DB_MASTER_USERNAME']}\n")
  fh.flush

  loop do
    fh.write("#{Time.now} #{counter}\n")
    fh.flush
    counter += 1
    sleep(1.0)
  end
end