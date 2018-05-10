#!/bin/bash -xe

. ~/.profile

cd /home/ubuntu/primary_repo/ruby

echo "installing bundler..."
gem install bundler

echo "running bundle install..."
RAILS_ENV=production bundle install

echo "running event create..."
RAILS_ENV=production bundle exec rake event:create[4d0e84d6-60db-4756-9289-9fc4cdd12a58,0.1,1.0,0.0,10,1000]
