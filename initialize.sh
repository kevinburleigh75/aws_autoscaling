#!/bin/bash

sudo -H -i -u ubuntu bash -c "aws configure set s3.signature_version s3v4"
sudo -H -i -u ubuntu bash -c "aws s3api get-object --bucket secrets-exper --key secrets .secrets"

PROFILE_FILENAME="/home/ubuntu/.profile"
AWSINFO_FILENAME="/home/ubuntu/.awsinfo"

if [ ! -f $AWSINFO_FILENAME ]; then
  AWS_INSTANCE_ID="$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)"
  AWS_REGION="$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk '{print $3}' | sed -e 's/"//g' | sed -e 's/,//g')"
  aws configure set region $AWS_REGION
  AWS_ASG_NAME="$(aws autoscaling describe-auto-scaling-instances --instance-ids=$AWS_INSTANCE_ID --query 'AutoScalingInstances[0].AutoScalingGroupName' | sed -e 's/"//g')"
  AWS_ASG_MAX_SIZE="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $AWS_ASG_NAME --query 'AutoScalingGroups[0].MaxSize' | sed -e 's/"//g')"

  echo AWS_INSTANCE_ID=$AWS_INSTANCE_ID >> $AWSINFO_FILENAME
  echo AWS_REGION=$AWS_REGION >> $AWSINFO_FILENAME
  echo AWS_ASG_NAME=$AWS_ASG_NAME >> $AWSINFO_FILENAME
  echo AWS_ASG_MAX_SIZE=$AWS_ASG_MAX_SIZE >> $AWSINFO_FILENAME

  echo "if [ -f .awsinfo ]; then" >> $PROFILE_FILENAME
  echo "    . .awsinfo" >> $PROFILE_FILENAME
  echo "fi" >> $PROFILE_FILENAME
fi

sudo -H -i -u ubuntu bash -c "aws configure set region $AWS_REGION"

(cd /home/ubuntu/primary_repo/services; /home/ubuntu/.rvm/rubies/ruby-2.3.1/bin/ruby ./install_services.rb kevin . /etc/systemd/system/)
