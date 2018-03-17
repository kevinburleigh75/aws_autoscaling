#!/bin/bash -xe

systemctl enable  kevin_external_server
systemctl restart kevin_external_server

until curl localhost:3000/ping
do
  echo waiting for server...
  sleep 1
done
