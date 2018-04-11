#!/usr/bin/env ruby

require 'awesome_print'
require 'jmespath'

require 'aws-sdk-cloudformation'
require 'aws-sdk-cloudwatch'
require 'aws-sdk-ec2'

region = 'us-east-1'

elb_name =
cf = Aws::CloudFormation::Resource.new

cf.stacks.each do |stack|
  puts "STACK #{stack.name}"
  template_json = cf.client.get_template(stack_name: stack.name).template_body
  template = JSON.parse(template_json)
  puts template
  puts template.class
  # puts JMESPath.search('foo[*].name', {foo: [{name: "one"}, {name: "two"}]})
  ap JMESPath.search('Parameters', template)
  ap JMESPath.search('Parameters.*.Description', template)
end
