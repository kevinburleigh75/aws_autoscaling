#!/bin/bash -xe

. ~/.profile

cd /home/ubuntu/primary_repo/ruby

echo "running bundle install..."
RAILS_ENV=production bundle install

echo "starting rake task..."
RAILS_ENV=production bundle exec rake demo2:monitor[63efccce-67d8-4737-9bd0-7c1307eed82d]
