#!/usr/bin/env ruby

require 'awesome_print'
require 'byebug'
require 'jmespath'
require 'json'
require 'slop'

require 'aws-sdk-autoscaling'
require 'aws-sdk-cloudformation'
require 'aws-sdk-ec2'

def get_nested_stacks(parent_stack_name:)
  client = Aws::CloudFormation::Client.new

  stacks = client.describe_stacks.stacks.select{ |stack|
    stack.stack_name =~ %r/^#{parent_stack_name}$|^#{parent_stack_name}-/
  }

  stacks
end

def get_asg_resources(stacks:)
  asg_resources = stacks.map do |stack|
    get_stack_asg_resources(stack_name: stack.stack_name)
  end.flatten.compact

  asg_resources
end

def get_stack_asg_resources(stack_name:)
  client = Aws::CloudFormation::Client.new

  asg_resources = client.describe_stack_resources(stack_name: stack_name)
                        .stack_resources
                        .select{ |resource|
                          resource.resource_type == 'AWS::AutoScaling::AutoScalingGroup'
                        }

  asg_resources
end

def get_asgs(asg_resources:)
  client = Aws::AutoScaling::Client.new

  asg_names = asg_resources.map{|resource| resource.physical_resource_id}
  asgs = client.describe_auto_scaling_groups(auto_scaling_group_names: asg_names)
               .auto_scaling_groups

  asgs
end

def split_asgs(asgs:)
  migration_asgs     = asgs.select{|asg| asg.auto_scaling_group_name =~ %r/Migration/}
  non_migration_asgs = asgs.select{|asg| asg.auto_scaling_group_name !~ %r/Migration/}

  return migration_asgs, non_migration_asgs
end

def get_asg_lcs(asgs:)
  client = Aws::AutoScaling::Client.new

  lcs = asgs.map do |asg|
    client.describe_launch_configurations(launch_configuration_names: [asg.launch_configuration_name])
          .launch_configurations
  end.flatten.compact

  lcs
end

def update_stack(stack_name:,
                 template_url:,
                 non_migration_asgs:,
                 non_migration_image_id:,
                 migration_asg:,
                 migration_image_id:,
                 is_migration:)
  client = Aws::CloudFormation::Client.new

  client.update_stack(
    stack_name:   stack_name,
    template_url: template_url,
    parameters: [
      {
        parameter_key:   'EnvName',
        parameter_value: 'blah',
      },
      {
        parameter_key:   'RepoUrl',
        parameter_value: 'https://github.com/kevinburleigh75/aws_autoscaling.git',
      },
      {
        parameter_key:   'BranchNameOrSha',
        parameter_value: 'klb_elb_expers',
      },
      {
        parameter_key:   'KeyName',
        parameter_value: 'kevin_va_kp',
      },
      {
        parameter_key:   'ElbAsgStackTemplateUrl',
        parameter_value: 'https://s3.amazonaws.com/kevin-templates/ElbAsgTemplate.json',
      },
      {
        parameter_key:   'SimpleAsgStackTemplateUrl',
        parameter_value: 'https://s3.amazonaws.com/kevin-templates/SimpleAsgTemplate.json',
      },
      {
        parameter_key:   'NonMigrationImageId',
        parameter_value: non_migration_image_id,
      },
      {
        parameter_key:   'MigrationImageId',
        parameter_value: migration_image_id,
      },
      {
        parameter_key:   'MigrationAsgDesiredCapacity',
        parameter_value: is_migration ? '1' : '0',
      },
    ].concat(non_migration_asgs.map{ |asg|
      match_data = /^.+-(?<asg_name>.+?)Stack-/.match(asg.auto_scaling_group_name)
      {
        parameter_key:   "#{match_data['asg_name']}DesiredCapacity",
        parameter_value: asg.desired_capacity.to_s,
      }
    })
  )
end

def adjust_freeze(stack_name:,
                  asgs:,
                  is_freeze:)
  client = Aws::AutoScaling::Client.new

  if is_freeze
    asgs.each do |asg|
      client.create_or_update_tags({
        tags: [
          {
            key: 'FreezeAutoscalingEvents',
            propagate_at_launch: false,
            resource_id: asg.auto_scaling_group_name,
            resource_type: 'auto-scaling-group',
          }
        ]
      })
    end
  else
    asgs.each do |asg|
      client.delete_tags({
        tags: [
          {
            key: 'FreezeAutoscalingEvents',
            resource_id: asg.auto_scaling_group_name,
            resource_type: 'auto-scaling-group',
          }
        ]
      })
    end
  end

  ap asgs.last
end

def main
  opts = Slop.parse do |slop|
    slop.on '--help', 'show this help' do
      puts slop
      exit
    end
    slop.string '--stack_name', 'name of stack to modify', required: true
    slop.string '--template_url', 'template S3 URL'
    slop.string '--old_image_id', 'old AMI ID (just to be safe)'
    slop.string '--new_image_id', 'new AMI ID'
    slop.bool   '--migrate', 'deploy only to migration ASG (cannot be used with --deploy, --freeze, --unfreeze)'
    slop.bool   '--deploy', 'deploy only to non-migration ASGs (cannot be used with --migrate, --freeze, --unfreeze)'
    slop.bool   '--freeze', 'freeze autoscaling events (cannot be used with --deploy, --migrate, --unfreeze)'
    slop.bool   '--unfreeze', 'unfreeze autoscaling events (cannot be used with --deploy, --migrate, --freeze)'
  end
  opt_stack_name   = opts[:stack_name]
  opt_template_url = opts[:template_url]
  opt_old_image_id = opts[:old_image_id]
  opt_new_image_id = opts[:new_image_id]
  opt_migrate      = opts[:migrate]
  opt_deploy       = opts[:deploy]
  opt_freeze       = opts[:freeze]
  opt_unfreeze       = opts[:unfreeze]

  unless opt_migrate ^ opt_deploy ^ opt_freeze ^ opt_unfreeze
    abort('exactly one of --migrate, --deploy, --freeze, --unfreeze must be specified')
  end

  unless (opt_freeze || opt_unfreeze) || ( (opt_migrate || opt_deploy) && opt_template_url && opt_old_image_id && opt_new_image_id)
    abort('must specify --template_url, --old_image_id, and --new_image_id unless --freeze, --unfreeze')
  end

  stacks        = get_nested_stacks(parent_stack_name: opt_stack_name)
  asg_resources = get_asg_resources(stacks: stacks)
  asgs          = get_asgs(asg_resources: asg_resources)

  migration_asgs, non_migration_asgs = split_asgs(asgs: asgs)

  if migration_asgs.count != 1
    abort("unexpected number of migration ASGs (#{migration_asgs.count})")
  end

  migration_asg = migration_asgs.first

  migration_lc      = get_asg_lcs(asgs: [migration_asg])[0]
  non_migration_lcs = get_asg_lcs(asgs: non_migration_asgs)

  if opt_migrate || opt_deploy
    update_stack(
      stack_name:             opt_stack_name,
      template_url:           opt_template_url,
      non_migration_asgs:     non_migration_asgs,
      non_migration_image_id: opt_migrate ? opt_old_image_id : opt_new_image_id,
      migration_asg:          migration_asg,
      migration_image_id:     opt_new_image_id,
      is_migration:           opt_migrate,
    )
  else
    adjust_freeze(
      stack_name: opt_stack_name,
      asgs:       asgs,
      is_freeze:  opt_freeze,
    )
  end
end

main
