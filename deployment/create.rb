#!/usr/bin/env ruby

require 'awesome_print'
require 'byebug'
require 'jmespath'
require 'json'
require 'slop'

require './deploy_utils'

def main
  opts = Slop.parse do |slop|
    slop.on '--help', 'show this help' do
      puts slop
      exit
    end
    slop.string '--stack_name', 'name of stack to modify', required: true
    slop.string '--template_url', 'template S3 URL', required: true
    slop.string '--image_id', 'AMI ID', required: true
    slop.bool   '--init_asgs', 'set initial ASG desired capacities (cannot be used with --db)'
  end
  opt_stack_name   = opts[:stack_name]
  opt_template_url = opts[:template_url]
  opt_image_id     = opts[:image_id]
  opt_init_asgs    = opts[:init_asgs]

  stacks        = DeployUtils.get_nested_stacks(parent_stack_name: opt_stack_name)
  asg_resources = DeployUtils.get_asg_resources(stacks: stacks)
  asgs          = DeployUtils.get_asgs(asg_resources: asg_resources)

  if opt_init_asgs
    DeployUtils.update_elb_stack_for_create(
      stack_name:             opt_stack_name,
      template_url:           opt_template_url,
      image_id:               opt_image_id,
    )
  else
    DeployUtils.create_elb_stack(
      stack_name:             opt_stack_name,
      template_url:           opt_template_url,
      image_id:               opt_image_id,
    )
  end
end

main
