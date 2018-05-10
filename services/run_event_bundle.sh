#!/bin/bash -xe

. ~/.profile

cd /home/ubuntu/primary_repo/ruby

echo "installing bundler..."
gem install bundler

echo "running bundle install..."
RAILS_ENV=production bundle install

echo "running event bundle..."
RAILS_ENV=production bundle exec rake event:bundle[a92ff02b-46c4-4bf2-8568-4df22b8ec956,0.1,1.0,0.0]
