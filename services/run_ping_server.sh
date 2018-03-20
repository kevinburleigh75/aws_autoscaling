#!/bin/bash -xe

. ~/.profile

cd /home/ubuntu
mkdir -p ping_server
cd ping_server
touch ping

echo "starting ping server..."
python -m SimpleHTTPServer 8000
