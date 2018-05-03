#!/bin/bash -xe

. ~/.profile

cd /home/ubuntu/primary_repo/ruby

echo "installing bundler..."
gem install bundler

echo "running bundle install..."
RAILS_ENV=production bundle install

echo "running creation..."
until RAILS_ENV=production DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:drop db:create db:migrate
do
  echo "migration failed - trying again..."
  touch /home/ubuntu/creation_failed.txt
  sleep 2
done
echo "creation completed"

touch /home/ubuntu/creation_successful.txt
