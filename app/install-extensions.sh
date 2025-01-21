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

wget https://github.com/league-infrastructure/league-vscode-ext/releases/download/v0.0.3/jtl-vscode-0.0.3.vsix
code-server --install-extension jtl-vscode-0.0.3.vsix
