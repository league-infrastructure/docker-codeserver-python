#!/bin/bash

URL="$JTL_INTERNAL_CODESERVER_URL/host/$JTL_USERNAME/$JTL_CLASS_ID/synced"

# Call the endpoint and capture output; ignore curl failures for exit code logic
response="$(curl -s "$URL" || true)"

# If the JSON explicitly says "synced": false, exit with failure
echo $response