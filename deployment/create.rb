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
  end
  opt_stack_name   = opts[:stack_name]
  opt_template_url = opts[:template_url]
  opt_image_id     = opts[:image_id]

  stacks        = DeployUtils.get_nested_stacks(parent_stack_name: opt_stack_name)
  asg_resources = DeployUtils.get_asg_resources(stacks: stacks)
  asgs          = DeployUtils.get_asgs(asg_resources: asg_resources)

  creation_asg, non_creation_asgs = DeployUtils.split_asgs_for_creation(asgs: asgs)

  DeployUtils.create_elb_stack(
    stack_name:             opt_stack_name,
    template_url:           opt_template_url,
    creation_asg:           creation_asg,
    non_creation_asgs:      non_migration_asgs,
    image_id:               opt_image_id,
  )
end

main
