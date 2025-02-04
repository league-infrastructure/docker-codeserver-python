#!/bin/bash

# 

echo "Installing VSCode extensions..."

# Install VSCode extensions
code-server --install-extension "ms-python.python" \
    --install-extension "ms-python.autopep8" \
    --install-extension "ms-python.debugpy" \
    --install-extension "ms-python.isort" \
    --install-extension "ms-toolsai.jupyter" \
    --install-extension /app/vsc/jtl-vscode-0.2.2.vsix
