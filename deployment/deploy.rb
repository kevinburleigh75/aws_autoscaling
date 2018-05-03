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
    slop.string '--old_image_id', 'old AMI ID (just to be safe)', required: true
    slop.string '--new_image_id', 'new AMI ID', required: true
    slop.bool   '--migrate', 'deploy only to migration ASG (cannot be used with --deploy)'
    slop.bool   '--deploy', 'deploy only to non-migration ASGs (cannot be used with --migrate)'
  end
  opt_stack_name   = opts[:stack_name]
  opt_template_url = opts[:template_url]
  opt_old_image_id = opts[:old_image_id]
  opt_new_image_id = opts[:new_image_id]
  opt_migrate      = opts[:migrate]
  opt_deploy       = opts[:deploy]

  unless opt_migrate ^ opt_deploy
    abort('exactly one of --migrate or --deploy must be specified')
  end

  stacks        = DeployUtils.get_nested_stacks(parent_stack_name: opt_stack_name)
  asg_resources = DeployUtils.get_asg_resources(stacks: stacks)
  asgs          = DeployUtils.get_asgs(asg_resources: asg_resources)

  migration_asgs, non_migration_asgs = DeployUtils.split_asgs(asgs: asgs)

  if migration_asgs.count != 1
    abort("unexpected number of migration ASGs (#{migration_asgs.count})")
  end

  migration_asg = migration_asgs.first

  migration_lc      = DeployUtils.get_asg_lcs(asgs: [migration_asg])[0]
  non_migration_lcs = DeployUtils.get_asg_lcs(asgs: non_migration_asgs)

  DeployUtils.update_stack(
    stack_name:             opt_stack_name,
    template_url:           opt_template_url,
    non_migration_asgs:     non_migration_asgs,
    non_migration_image_id: opt_migrate ? opt_old_image_id : opt_new_image_id,
    migration_asg:          migration_asg,
    migration_image_id:     opt_new_image_id,
    is_migration:           opt_migrate,
  )
end

main
