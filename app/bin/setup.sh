#!/bin/bash

# Post startup installation script, which is run from 
# supervisord after the container has started.

USER_DATA_DIR="$HOME/.local/share/code-server" # must match code-server.yaml

echo "Setup.sh "

 mkdir -p /home/vscode/.config/rclone/
 touch /home/vscode/.config/rclone/rclone.conf

cd /workspace


# Install the user configuration. Note that this is the User configuration
# and that the repo may also have a custom workspace configuration

SETTINGS_SRC="/app/vsc/settings.json"
USER_SETTINGS="$USER_DATA_DIR/User/settings.json"

if [ -z "$SETTINGS_SRC" ]; then
    echo "USER_CONFIG is not set; not installing user configuration"
else
    echo "Installing user configuration from $SETTINGS_SRC to $USER_SETTINGS"
    cp  $SETTINGS_SRC $USER_SETTINGS
fi

clone_and_setup_repo() {
    target_dir=$WORKSPACE_FOLDER


    if [ -d "$target_dir" ]; then
        echo "Repository exists, pulling latest changes in $target_dir"
        cd $target_dir
        git pull
    else
        echo "Empty, cloning repo $JTL_REPO to $target_dir "
        git clone --depth 1 "$JTL_REPO" $target_dir
        cd $target_dir
    fi


    # Find and run the repo setup script. 
    if [ -z "$SETUP_SCRIPT" ]; then
        SETUP_SCRIPT="${target_dir}/.jtl/setup.sh"
    else
        SETUP_SCRIPT="${target_dir}/${SETUP_SCRIPT}"
    fi

    if [ -f "$SETUP_SCRIPT" ]; then
        echo "Running setup script from cloned repo ${target_dir} ..."
        /bin/bash "$SETUP_SCRIPT" "$target_dir"
    fi
}

if [ -z "$JTL_REPO" ]; then
    echo "JTL_REPO is not set; not cloning anything"
else
    clone_and_setup_repo
fi

# Export environment variables for cron jobs
echo "Exporting environment variables for cron jobs to /app/env.sh"
cat <<EOF > $HOME/env.sh
export WORKSPACE_FOLDER="${WORKSPACE_FOLDER}"
export JTL_SPAWNER_URL="${JTL_SPAWNER_URL}"
export JTL_USERNAME="${JTL_USERNAME}"
export JTL_HOST_UUID="${JTL_HOST_UUID}"
EOF


# Inject our workspace settings into the workspace .vscode/settings.json. Some of these may
# apply only to this docker image, so we can't just put them into the repo.
if [ -f "${WORKSPACE_FOLDER}/.vscode/settings.json" ]; then
    jq ". + $(< /app/vsc/workspace-settings.json)" "${WORKSPACE_FOLDER}/.vscode/settings.json" > "${WORKSPACE_FOLDER}/.vscode/settings.json.tmp" \
    && mv "${WORKSPACE_FOLDER}/.vscode/settings.json.tmp" "${WORKSPACE_FOLDER}/.vscode/settings.json"
else
    mkdir -p "${WORKSPACE_FOLDER}/.vscode"
    cp /app/vsc/workspace-settings.json "${WORKSPACE_FOLDER}/.vscode/settings.json"
fi


# Install the ipykernel for Jupyter support in VS Code
python -m ipykernel install --user --name codehost --display-name "Python (League Code Host)"

# Force all notebooks to prefer this kernel
/app/bin/updateks.py codehost


echo "Setup.sh finished"
