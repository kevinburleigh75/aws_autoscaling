#!/bin/bash

aws autoscaling set-instance-health --instance-id $AWS_INSTANCE_ID --health-status Healthy
