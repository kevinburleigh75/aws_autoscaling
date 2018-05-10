#!/bin/bash -xe

systemctl enable  kevin_event_fetch_server
systemctl restart kevin_event_fetch_server
