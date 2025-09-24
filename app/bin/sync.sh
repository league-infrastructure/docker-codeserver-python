#!/bin/bash

# First positional arg: action (copy_in, copy_out, sync). Default: sync
action="${1:-sync}"

exec curl "$JTL_INTERNAL_CODESERVER_URL/host/$JTL_USERNAME/$action?host_uuid=$JTL_HOST_UUID"
