#!/bin/bash

# Post startup installation script, which is run from 
# supervisord after the container has started.

echo "Extra setup ... "

cd /workspace

# The code.json file is used to configure the Coder IDE, but it
# will also set the default workspace, which we don't want.
# Maybe would be better to edit out the default workspace part?
if [ -f /workspace/coder.json ]; then
    echo "Removing /workspace/coder.json ..."
    rm /workspace/coder.json
fi

if [ -z "$INITIAL_GIT_REPO" ]; then
    echo "INITIAL_GIT_REPO is not set; not cloning anything"
else

    target_dir=$(basename "$INITIAL_GIT_REPO" .git)

    if [ -d "$target_dir" ]; then
        echo "Repository already exists."
        exit 1
    fi

    git clone --depth 1 "$INITIAL_GIT_REPO" $target_dir

    if [ -z "$SETUP_SCRIPT" ]; then
        SETUP_SCRIPT="${target_dir}/.devcontainer/jtl-setup.sh"
    else
        SETUP_SCRIPT="${target_dir}/${SETUP_SCRIPT}"
    fi

    setup_script="${target_dir}/.devcontainer/jtl-setup.sh"

    if [ -f "$setup_script" ]; then
        echo "Running setup script from cloned repo ${target_dir} ..."
        cd $target_dir
        /bin/bash "$setup_script" "$target_dir"
    fi
fi
