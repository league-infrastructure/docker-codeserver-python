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

