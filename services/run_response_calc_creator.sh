#!/bin/bash -xe

. .profile

cd /home/ubuntu/aws_autoscaling/ruby
RAILS_ENV=production bundle exec rake demo1:response_calc[1125ed96-3f2f-49dc-b8e2-58302de77777,0.1,1,0]
