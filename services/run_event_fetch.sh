#!/bin/bash -xe

. ~/.profile

cd /home/ubuntu/primary_repo/ruby

echo "installing bundler..."
gem install bundler

echo "running bundle install..."
RAILS_ENV=production bundle install

echo "running event fetch..."
RAILS_ENV=production bundle exec rake event:fetch[378a71f0-0294-48d6-8796-c06a7ef27ea5,0.1,1.0,0.0,fetch01]
