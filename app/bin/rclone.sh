#!/bin/bash



set -euo pipefail

RCARGS="--log-level INFO"

# Check required env vars
: "${WORKSPACE_FOLDER:?WORKSPACE_FOLDER is required}"
: "${STORAGE_BUCKET:?STORAGE_BUCKET is required}"
: "${JTL_CLASS_ID:?JTL_CLASS_ID is required}"
: "${JTL_USERNAME:?JTL_USERNAME is required}"
: "${STORAGE_ENDPOINT:?STORAGE_ENDPOINT is required}"

# Must be set for env_auth=true
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID is required for env_auth=true}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY is required for env_auth=true}"

LOCAL_PATH="$WORKSPACE_FOLDER"

# Normalize endpoint: strip any scheme (rclone just wants the host)
ENDPOINT_HOST="${STORAGE_ENDPOINT#http://}"
ENDPOINT_HOST="${ENDPOINT_HOST#https://}"

# Build remote object key
REMOTE_KEY="${STORAGE_BUCKET}/class_${JTL_CLASS_ID}/${JTL_USERNAME}${WORKSPACE_FOLDER}"

# Inline backend, credentials pulled from environment
REMOTE_SPEC=":s3,provider=DigitalOcean,env_auth=true,endpoint=${ENDPOINT_HOST}:${REMOTE_KEY}"

# Usage: rclone.sh <copy|sync> <in|out>
# Arguments:
#   copy|sync: Specify the operation type.
#   in: Sync from remote to local.
#   out: Sync from local to remote.
# Required Environment Variables:
#   WORKSPACE_FOLDER: The workspace folder path.
#   STORAGE_BUCKET: The storage bucket name.
#   JTL_CLASS_ID: The JTL class ID.
#   JTL_USERNAME: The JTL username.
#   STORAGE_ENDPOINT: The storage endpoint URL.
#   AWS_ACCESS_KEY_ID: AWS access key ID (required for env_auth=true).
#   AWS_SECRET_ACCESS_KEY: AWS secret access key (required for env_auth=true).

# Check if two arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 {copy|sync} {in|out}"
    exit 1
fi

# Check for the first and second arguments
if [ "$1" == "copy" ] || [ "$1" == "sync" ]; then
    if [ "$2" == "in" ]; then
        exec rclone $RCARGS $1 "$REMOTE_SPEC" "$LOCAL_PATH"
    elif [ "$2" == "out" ]; then
        exec rclone $RCARGS $1 "$LOCAL_PATH" "$REMOTE_SPEC"
    else
        echo "Usage: $0 {copy|sync} {in|out}"
        exit 1
    fi
else
    echo "Usage: $0 {copy|sync} {in|out}"
    exit 1
fi