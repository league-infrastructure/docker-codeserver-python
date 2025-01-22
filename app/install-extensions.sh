#!/bin/bash

# List of extensions to install
extensions=(
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.autopep8"
    "ms-python.debugpy"
    "ms-python.isort"
    "ms-toolsai.jupyter"
)

for extension in "${extensions[@]}"; do
    code-server --install-extension "$extension" 
done

# Install the League extension
wget https://github.com/league-infrastructure/league-vscode-ext/releases/download/v0.1.0/v0.1.0.vsix
code-server --install-extension v0.1.0.vsix
