#!/bin/bash -xe

systemctl enable  kevin_external_server
systemctl restart kevin_external_server

systemctl enable  kevin_external_server_monitor
systemctl restart kevin_external_server_monitor
