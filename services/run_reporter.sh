#!/bin/bash -xe

. ~/.profile

cd /home/ubuntu/aws_autoscaling/ruby
RAILS_ENV=production bundle install
RAILS_ENV=production bundle exec rake demo1:report[1125ed96-3f2f-49dc-b8e2-58302de99999,0.25,1,0]