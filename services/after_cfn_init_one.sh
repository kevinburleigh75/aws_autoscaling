#!/bin/bash -xe

systemctl enable  kevin_external_server
systemctl restart kevin_external_server

systemctl enable  kevin_ping_server
systemctl restart kevin_ping_server

until curl localhost:8000/ping
do
  echo waiting for ping server...
  sleep 1
done

until curl localhost:3000/ping
do
  echo waiting for rails server...
  sleep 1
done

