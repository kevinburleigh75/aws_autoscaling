#!/usr/bin/env ruby

require 'fileutils'

service_prefix          = ARGV[0]
services_source_dirname = ARGV[1]
services_target_dirname = ARGV[2]
enabled_services        = Array(ARGV[3..-1])

##
## Clean up any existing services.
##

Dir.foreach(services_source_dirname) do |filename|
  puts("filename = #{filename}")
  if matches = filename.match(%r{^(.*/)*(?<service_name>.*)\.service$})
    service_name = matches[:service_name]
    next unless service_name.match(%r/^#{service_prefix}/)
    puts "disabling #{service_name}"
    system("systemctl disable #{service_name}")
    FileUtils.rm_f(services_target_dirname + '/' + service_name + '.service')
  end
end

##
## Install all services.
##

Dir.foreach(services_source_dirname) do |filename|
  puts("filename = #{filename}")
  if matches = filename.match(%r{^(.*/)*(?<service_name>.*)\.service$})
    service_name = matches[:service_name]
    puts("copying #{service_name}")
    FileUtils.cp(filename, services_target_dirname)
  end
end

##
## Enable specified services.
##

enabled_services.each do |service_name|
  puts "enabling #{service_name}"
  system("systemctl enable #{service_name}")
  system("systemctl restart #{service_name}")
end
