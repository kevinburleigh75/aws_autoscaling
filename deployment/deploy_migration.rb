#!/usr/bin/env ruby

require 'slop'
require 'json'
require 'awesome_print'
require 'byebug'

def fetch_stack_info(stack_name:, template_url:)
  cmd = <<~ENDCMD
  aws cloudformation describe-stacks \
    --stack-name #{stack_name} \
    --output json
  ENDCMD
  puts "cmd = (#{cmd})"

  json = `#{cmd}`
  parsed_json = JSON.parse(json)

  stack_info = {
    stack_name:   stack_name,
    stack_status: parsed_json["Stacks"][0]["StackStatus"],
    template_url: template_url,
  }

  return stack_info
end

def fetch_asg_physical_resource_ids(stack_info:)
  cmd = <<~ENDCMD
  aws cloudformation describe-stack-resources \
    --stack-name #{stack_info[:stack_name]} \
    --query 'StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId' \
    --output json
  ENDCMD

  puts "cmd = (#{cmd})"
  json = `#{cmd}`
  return JSON.parse(json)
end

def fetch_asg_current_info(asg_physical_id:)
  asg_info = {
    asg_physical_id: asg_physical_id
  }

  cmd = <<~ENDCMD
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names #{asg_physical_id} \
    --query 'AutoScalingGroups[*].[DesiredCapacity,LaunchConfigurationName]' \
    --output json
  ENDCMD
  puts "cmd = (#{cmd})"

  json = `#{cmd}`
  parsed_json = JSON.parse(json)

  asg_info[:desired_capacity] = parsed_json[0][0]
  asg_info[:lc_physical_id]   = parsed_json[0][1]

  image_id = fetch_lc_image_id(lc_physical_id: asg_info[:lc_physical_id])
  asg_info[:lc_image_id] = image_id

  return asg_info
end

def fetch_lc_image_id(lc_physical_id:)
  cmd = <<~ENDCMD
  aws autoscaling describe-launch-configurations \
    --launch-configuration-names #{lc_physical_id} \
    --query 'LaunchConfigurations[*].ImageId' \
    --output json
  ENDCMD
  puts "cmd = (#{cmd})"

  json = `#{cmd}`
  lc_image_id = JSON.parse(json)[0]
  return lc_image_id
end

def wait_for_update_to_complete(stack_info:)
  cmd = <<~ENDCMD
  aws cloudformation wait stack-update-complete \
    --stack-name #{stack_info[:stack_name]} \
    --output json
  ENDCMD
  puts "cmd = (#{cmd})"

  json = `#{cmd}`
end

def start_migration_server(image_info:, stack_info:, migration_asg_info:, non_migration_asg_infos:)
  asg1_desired_capacity = non_migration_asg_infos.detect{|info| info[:asg_physical_id] =~ %r{Asg1}}[:desired_capacity]

  cmd = <<~ENDCMD
  aws cloudformation update-stack \
    --stack-name #{stack_info[:stack_name]} \
    --template-url #{stack_info[:template_url]} \
    --parameters \
        ParameterKey=EnvName,ParameterValue=blah \
        ParameterKey=BranchNameOrSha,ParameterValue=klb_elb_expers \
        ParameterKey=KeyName,ParameterValue=kevin_va_kp \
        ParameterKey=RepoUrl,ParameterValue=https://github.com/kevinburleigh75/aws_autoscaling.git \
        ParameterKey=LcImageId,ParameterValue=#{image_info[:old_image_id]} \
        ParameterKey=MigrationLcImageId,ParameterValue=#{image_info[:new_image_id]} \
        ParameterKey=MigrationDesiredCapacity,ParameterValue=1 \
        ParameterKey=Asg1DesiredCapacity,ParameterValue=#{asg1_desired_capacity} \
    --output json
  ENDCMD
  puts "cmd = (#{cmd})"

  json = `#{cmd}`
end

def wait_for_migration_to_complete(migration_asg_info:)
  cmd1 = <<~ENDCMD
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names #{migration_asg_info[:asg_physical_id]} \
    --query 'AutoScalingGroups[*].Instances[0].InstanceId' \
    --output json
  ENDCMD
  puts "cmd1 = (#{cmd1})"

  json1 = `#{cmd1}`
  migration_instance_id = JSON.parse(json1)[0]

  cmd2 = <<~ENDCMD
  aws ec2 describe-instances \
    --instance-ids #{migration_instance_id} \
    --query 'Reservations[0].Instances[*].PublicIpAddress' \
    --output json
  ENDCMD
  puts "cmd2 = (#{cmd2})"

  json2 = `#{cmd2}`
  migration_instance_ip_addr = JSON.parse(json2)[0]

  cmd3 = <<~ENDCMD
  ssh -oStrictHostKeyChecking=no -i ~/.ssh/kevin_va_kp.pem -t ubuntu@#{migration_instance_ip_addr} ls
  ENDCMD

  success = loop do
    puts "cmd3 = (#{cmd3})"
    output = `#{cmd3}`
    break true   if output =~ %r{success}
    break false  if output =~ %r{fail}
    sleep 2
  end

  if success
    puts "migrations were successful"
  else
    puts "migrations failed"
  end
end

def stop_migration_server(image_info:, stack_info:, migration_asg_info:, non_migration_asg_infos:)
  asg1_desired_capacity = non_migration_asg_infos.detect{|info| info[:asg_physical_id] =~ %r{Asg1}}[:desired_capacity]

  cmd = <<~ENDCMD
  aws cloudformation update-stack \
    --stack-name #{stack_info[:stack_name]} \
    --template-url #{stack_info[:template_url]} \
    --parameters \
        ParameterKey=EnvName,ParameterValue=blah \
        ParameterKey=BranchNameOrSha,ParameterValue=klb_elb_expers \
        ParameterKey=KeyName,ParameterValue=kevin_va_kp \
        ParameterKey=RepoUrl,ParameterValue=https://github.com/kevinburleigh75/aws_autoscaling.git \
        ParameterKey=LcImageId,ParameterValue=#{image_info[:old_image_id]} \
        ParameterKey=MigrationLcImageId,ParameterValue=#{image_info[:new_image_id]} \
        ParameterKey=MigrationDesiredCapacity,ParameterValue=0 \
        ParameterKey=Asg1DesiredCapacity,ParameterValue=#{asg1_desired_capacity} \
    --output json
  ENDCMD
  puts "cmd = (#{cmd})"

  json = `#{cmd}`
end

def main
  opts = Slop.parse do |slop|
    slop.on '--help', 'show this help' do
      puts slop
      exit
    end
    slop.string '--template_url', 'template S3 URL', required: true
    slop.string '--stack_name', 'name of stack to modify', required: true
    slop.string '--old_image_id', 'old AMI ID (just to be safe)', required: true
    slop.string '--new_image_id', 'new AMI ID', required: true
  end

  stack_name = opts[:stack_name]
  image_id   = opts[:image_id]
  template_url = opts[:template_url]
  old_image_id = opts[:old_image_id]
  new_image_id = opts[:new_image_id]

  image_info = {
    new_image_id: new_image_id,
    old_image_id: old_image_id,
  }
  puts "image info:"
  ap image_info

  stack_info = fetch_stack_info(
    stack_name:   stack_name,
    template_url: template_url,
  )
  puts "stack info:"
  ap stack_info

  unless (stack_info[:stack_status] =~ %r{COMPLETE})
    puts "there appears to be another deployment/rollback in progress"
    exit
  end

  asg_ids = fetch_asg_physical_resource_ids(
    stack_info: stack_info
  )
  puts "ASG ids:"
  ap asg_ids

  asg_infos = asg_ids.map{|asg_id| fetch_asg_current_info(asg_physical_id: asg_id)}
  puts "ASG infos:"
  ap asg_infos

  image_mismatches = asg_infos.select{|info| info[:lc_image_id] != image_info[:old_image_id]}
  if image_mismatches.any?
    puts "the following resources do not have AMI #{old_image_id}:"
    ap image_mismatches
    exit
  end

  migration_asg_info      = asg_infos.detect{|info| info[:asg_physical_id] =~ %r{Migration}}
  non_migration_asg_infos = asg_infos.select{|info| info[:asg_physical_id] !~ %r{Migration}}

  puts "migration ASG info:"
  ap migration_asg_info

  puts "non-migration ASG infos:"
  ap non_migration_asg_infos

  unless (migration_asg_info[:desired_capacity] == 0)
    puts "there appears to be another migration in progress"
    exit
  end

  start_migration_server(
    image_info:              image_info,
    stack_info:              stack_info,
    migration_asg_info:      migration_asg_info,
    non_migration_asg_infos: non_migration_asg_infos
  )

  wait_for_update_to_complete(
    stack_info: stack_info
  )

  wait_for_migration_to_complete(
    migration_asg_info: migration_asg_info
  )

  stop_migration_server(
    image_info:              image_info,
    stack_info:              stack_info,
    migration_asg_info:      migration_asg_info,
    non_migration_asg_infos: non_migration_asg_infos
  )

  wait_for_update_to_complete(
    stack_info: stack_info
  )

end

main

