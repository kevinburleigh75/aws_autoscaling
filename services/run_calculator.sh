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
RAILS_ENV=production bundle exec rake demo2:calc[1125ed96-3f2f-49dc-b8e2-58302de88888,0.25,1,0]
