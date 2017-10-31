#!/bin/bash

INSTANCE_ID="$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)"
REGION="$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk '{print $3}' | sed -e 's/"//g' | sed -e 's/,//g')"
echo instance $INSTANCE_ID
echo region   $REGION

aws configure set region $REGION

ASG_NAME="$(aws autoscaling describe-auto-scaling-instances --instance-ids=$INSTANCE_ID --query 'AutoScalingInstances[0].AutoScalingGroupName' | sed -e 's/"//g')"
echo asg_name $ASG_NAME

MAX_SIZE="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0].MaxSize' | sed -e 's/"//g')"
echo max_size $MAX_SIZE

aws autoscaling set-desired-capacity --auto-scaling-group-name $ASG_NAME --desired-capacity $MAX_SIZE --no-honor-cooldown
