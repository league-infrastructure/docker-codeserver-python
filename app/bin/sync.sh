#!/bin/bash

# Calls unto the code-spawner application to sync data in or out to an S3
# compatible object store. The spawner executes the rclone program in th
# container. We do it this way so there are no credentials stored in the
# container.

# When the spawner calls back in, it will run /app/bin/rclone.sh to do the
# actual rclone command.

# This program is called from setup and cron. 

# First positional arg: action (sync_in, sync_out). Default: sync
action="${1:-sync}"

exec curl "$JTL_INTERNAL_CODESERVER_URL/host/$JTL_USERNAME/$action?host_uuid=$JTL_HOST_UUID"
