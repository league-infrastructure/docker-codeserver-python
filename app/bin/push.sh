#!/bin/bash
[ -f $HOME/env.sh ] && . $HOME/env.sh

# Request the code spawner to call back into the container to push data to the repo.
# This allows us to not have GITHUB credentials in the container.

cd "$WORKSPACE_FOLDER"
git add -A
if [ "$1" == "-f" ]; then
    echo "Force push requested; executing curl command."
    curl "$JTL_SPAWNER_URL/host/$JTL_USERNAME/push?host_uuid=$JTL_HOST_UUID"
else
    if ! git diff --cached --quiet; then
        echo "$(date) Changes detected; committing and pushing. "
        git commit -m "Auto-commit: workspace changes before push"
        curl "$JTL_SPAWNER_URL/host/$JTL_USERNAME/push?host_uuid=$JTL_HOST_UUID"
    else
        echo "$(date) No changes to commit; skipping push. "
    fi
fi