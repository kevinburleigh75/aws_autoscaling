#!/bin/bash

sudo -H -i -u ubuntu bash -c "aws configure set s3.signature_version s3v4"
sudo -H -i -u ubuntu bash -c "aws s3api get-object --bucket secrets-exper --key secrets .secrets"

sudo -H -i -u ubunto bash -c "/home/ubunutu/primary_repo/create_awsinfo.sh"
sudo -H -i -u ubuntu bash -c "aws configure set region $AWS_REGION"

(cd /home/ubuntu/primary_repo/services; /home/ubuntu/.rvm/rubies/ruby-2.3.1/bin/ruby ./install_services.rb kevin . /etc/systemd/system/)
