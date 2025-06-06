#!/bin/bash

# Post startup installation script, which is run from 
# supervisord after the container has started.

USER_DATA_DIR="$HOME/.local/share/code-server" # must match code-server.yaml

echo "Setup.sh: Extra setup  "

cd /workspace

mkdir /workspace/User

# The code.json file is used to configure the Coder IDE, but it
# will also set the default workspace, which we don't want.
# Maybe would be better to edit out the default workspace part?
if [ -f /workspace/coder.json ]; then
    echo "Removing /workspace/coder.json ..."
    rm /workspace/coder.json
fi

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
    target_dir=$(basename "$JTL_REPO" .git)

    if [ -d "$target_dir" ]; then
        echo "Repository already exists, pulling"

        cd $target_dir
        #git pull -X ours

        return 1
    fi

    git clone --depth 1 "$JTL_REPO" $target_dir

    cd $target_dir

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

echo "Setup.sh finished"
