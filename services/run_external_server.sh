#!/bin/bash -xe

. ~/.profile

cd /home/ubuntu/primary_repo/ruby

echo "running bundle install..."
RAILS_ENV=production bundle install

# echo "running migrations..."
# until RAILS_ENV=production bundle exec rake db:migrate
# do
#   echo "migration failed - trying again..."
#   sleep 2
# done
# echo "migrations completed"

echo "starting rake task..."
RAILS_ENV=production bundle exec rails server
