#!/bin/bash -xe

PROFILE_FILENAME="$HOME/.profile"
AWSINFO_FILENAME="$HOME/.awsinfo"

AWS_INSTANCE_ID="$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)"
AWS_REGION="$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk '{print $3}' | sed -e 's/"//g' | sed -e 's/,//g')"
aws configure set region $AWS_REGION
AWS_ASG_NAME="$(aws autoscaling describe-auto-scaling-instances --instance-ids=$AWS_INSTANCE_ID --query 'AutoScalingInstances[0].AutoScalingGroupName' | sed -e 's/"//g')"
AWS_ASG_LC_NAME="$(aws autoscaling describe-auto-scaling-instances --instance-ids=$AWS_INSTANCE_ID --query 'AutoScalingInstances[0].LaunchConfigurationName' | sed -e 's/"//g')"
AWS_ASG_LC_IMAGE_ID="$(aws autoscaling describe-launch-configurations --launch-configuration-names=$AWS_ASG_LC_NAME --query 'LaunchConfigurations[0].ImageId' | sed -e 's/"//g')"
AWS_ASG_MAX_SIZE="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $AWS_ASG_NAME --query 'AutoScalingGroups[0].MaxSize' | sed -e 's/"//g')"

echo export AWS_INSTANCE_ID=$AWS_INSTANCE_ID         >> $AWSINFO_FILENAME
echo export AWS_REGION=$AWS_REGION                   >> $AWSINFO_FILENAME
echo export AWS_ASG_NAME=$AWS_ASG_NAME               >> $AWSINFO_FILENAME
echo export AWS_ASG_LC_NAME=$AWS_ASG_LC_NAME         >> $AWSINFO_FILENAME
echo export AWS_ASG_LC_IMAGE_ID=$AWS_ASG_LC_IMAGE_ID >> $AWSINFO_FILENAME
echo export AWS_ASG_MAX_SIZE=$AWS_ASG_MAX_SIZE       >> $AWSINFO_FILENAME

echo ". $HOME/.awsinfo" >> $PROFILE_FILENAME

. $HOME/.awsinfo
