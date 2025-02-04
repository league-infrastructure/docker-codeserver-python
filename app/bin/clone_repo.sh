#!/usr/bin/bash

echo "Cloning repository..."

cd /workspace

if [ -d "$(basename "$INITIAL_GIT_REPO" .git)" ]; then
    echo "Repository already exists."
    exit 1
fi

git clone "$INITIAL_GIT_REPO"

