require 'aws-sdk-autoscaling'
require 'aws-sdk-cloudformation'
require 'aws-sdk-ec2'

module DeployUtils
  def self.get_nested_stacks(parent_stack_name:)
    client = Aws::CloudFormation::Client.new

    stacks = client.describe_stacks.stacks.select{ |stack|
      stack.stack_name =~ %r/^#{parent_stack_name}$|^#{parent_stack_name}-/
    }

    stacks
  end

  def self.get_asg_resources(stacks:)
    asg_resources = stacks.map do |stack|
      get_stack_asg_resources(stack_name: stack.stack_name)
    end.flatten.compact

    asg_resources
  end

  def self.get_stack_asg_resources(stack_name:)
    client = Aws::CloudFormation::Client.new

    asg_resources = client.describe_stack_resources(stack_name: stack_name)
                          .stack_resources
                          .select{ |resource|
                            resource.resource_type == 'AWS::AutoScaling::AutoScalingGroup'
                          }

    asg_resources
  end

  def self.get_asgs(asg_resources:)
    client = Aws::AutoScaling::Client.new

    asg_names = asg_resources.map{|resource| resource.physical_resource_id}
    asgs = client.describe_auto_scaling_groups(auto_scaling_group_names: asg_names)
                 .auto_scaling_groups

    asgs
  end

  def self.split_asgs(asgs:)
    migration_asgs     = asgs.select{|asg| asg.auto_scaling_group_name =~ %r/Migration/}
    non_migration_asgs = asgs.select{|asg| asg.auto_scaling_group_name !~ %r/Migration/}

    return migration_asgs, non_migration_asgs
  end

  def self.split_asgs_for_creation(asgs:)
    creation_asgs     = asgs.select{|asg| asg.auto_scaling_group_name =~ %r/Creation/}
    non_creation_asgs = asgs.select{|asg| asg.auto_scaling_group_name !~ %r/Creation/}

    if creation_asgs.count != 1
      abort("unexpected number of creation ASGs (#{creation_asgs.count})")
    end
    creation_asg = creation_asgs.first

    return creation_asg, non_creation_asgs
  end

  def self.get_asg_lcs(asgs:)
    client = Aws::AutoScaling::Client.new

    lcs = asgs.map do |asg|
      client.describe_launch_configurations(launch_configuration_names: [asg.launch_configuration_name])
            .launch_configurations
    end.flatten.compact

    lcs
  end

  def self.create_elb_stack(stack_name:,
                            template_url:,
                            image_id:,
                            init_asgs:)
    client = Aws::CloudFormation::Client.new

    client.create_stack(
      stack_name:   stack_name,
      template_url: template_url,
      parameters: [
        {
          parameter_key:   'VpcStackName',
          parameter_value: 'VpcStack',
        },
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
          parameter_value: 'master',
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
          parameter_value: image_id,
        },
        {
          parameter_key:   'MigrationImageId',
          parameter_value: image_id,
        },
        {
          parameter_key:   'MigrationAsgDesiredCapacity',
          parameter_value: '0',
        },
        {
          parameter_key:   'CreationAsgDesiredCapacity',
          parameter_value: '1',
        },
        ## TODO: figure out how to detect these automatically
        {
          parameter_key:   'OneAsgDesiredCapacity',
          parameter_value: '0',
        },
        {
          parameter_key:   'TwoAsgDesiredCapacity',
          parameter_value: '0',
        },
      ]
      # .concat(non_migration_asgs.map{ |asg|
      #   match_data = /^.+-(?<asg_name>.+?)Stack-/.match(asg.auto_scaling_group_name)
      #   {
      #     parameter_key:   "#{match_data['asg_name']}DesiredCapacity",
      #     parameter_value: '0',
      #   }
      # })
    )
  end

  def self.update_elb_stack_for_create(stack_name:,
                                       template_url:,
                                       image_id:)
    client = Aws::CloudFormation::Client.new

    client.update_stack(
      stack_name:   stack_name,
      template_url: template_url,
      parameters: [
        {
          parameter_key:   'VpcStackName',
          parameter_value: 'VpcStack',
        },
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
          parameter_value: 'master',
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
          parameter_value: image_id,
        },
        {
          parameter_key:   'MigrationImageId',
          parameter_value: image_id,
        },
        {
          parameter_key:   'MigrationAsgDesiredCapacity',
          parameter_value: '0',
        },
        {
          parameter_key:   'CreationAsgDesiredCapacity',
          parameter_value: '0',
        },
        ## TODO: figure out how to detect these automatically
        {
          parameter_key:   'OneAsgDesiredCapacity',
          parameter_value: '3',
        },
        {
          parameter_key:   'TwoAsgDesiredCapacity',
          parameter_value: '1',
        },
      ]
      # .concat(non_migration_asgs.map{ |asg|
      #   match_data = /^.+-(?<asg_name>.+?)Stack-/.match(asg.auto_scaling_group_name)
      #   {
      #     parameter_key:   "#{match_data['asg_name']}DesiredCapacity",
      #     parameter_value: '0',
      #   }
      # })
    )
  end

  def self.update_stack(stack_name:,
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
          parameter_key:   'VpcStackName',
          parameter_value: 'VpcStack',
        },
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
          parameter_value: 'master',
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
        {
          parameter_key:   'CreationAsgDesiredCapacity',
          parameter_value: '0',
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

  def self.adjust_freeze(stack_name:,
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
  end
end
