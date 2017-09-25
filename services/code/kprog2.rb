#!/usr/bin/env ruby

counter = 0
File::open('/home/ubuntu/log2.txt', 'a') do |fh|
  loop do
    fh.write("#{Time.now} #{counter}\n")
    fh.flush
    counter += 1
    sleep(1.0)
  end
end