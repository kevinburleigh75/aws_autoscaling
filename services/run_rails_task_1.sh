#!/bin/bash -xe

. .profile

cd /home/ubuntu/aws_autoscaling/ruby
RAILS_ENV=production bundle exec rake protocol:exper[1125ed96-3f2f-49dc-b8e2-58302de77619,1,1,0]
