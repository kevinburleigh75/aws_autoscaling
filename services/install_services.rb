#!/usr/bin/env ruby

require 'fileutils'

services_source_dirname = ARGV[0]
services_target_dirname = ARGV[1]

Dir.foreach(services_source_dirname) do |filename|
  puts("filename = #{filename}")
  if matches = filename.match(%r{^(.*/)*(?<service_name>.*)\.service$})
    service_name = matches[:service_name]
    puts("  service_name = #{service_name}")

    FileUtils.cp(filename, services_target_dirname)
    system("systemctl enable #{service_name}")
    system("systemctl restart #{service_name}")
  end
end
