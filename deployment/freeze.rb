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
    slop.bool   '--freeze', 'freeze autoscaling events (cannot be used with --unfreeze)'
    slop.bool   '--unfreeze', 'unfreeze autoscaling events (cannot be used with --freeze)'
  end
  opt_stack_name = opts[:stack_name]
  opt_freeze     = opts[:freeze]
  opt_unfreeze   = opts[:unfreeze]

  unless opt_freeze ^ opt_unfreeze
    abort('exactly one of --freeze or --unfreeze must be specified')
  end

  stacks        = DeployUtils.get_nested_stacks(parent_stack_name: opt_stack_name)
  asg_resources = DeployUtils.get_asg_resources(stacks: stacks)
  asgs          = DeployUtils.get_asgs(asg_resources: asg_resources)

  DeployUtils.adjust_freeze(
    stack_name: opt_stack_name,
    asgs:       asgs,
    is_freeze:  opt_freeze,
  )
end

main
