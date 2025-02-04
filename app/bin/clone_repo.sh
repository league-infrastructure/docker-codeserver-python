#!/usr/bin/bash

echo "Cloning repository..."

cd /workspace

if [ -d "$(basename "$INITIAL_GIT_REPO" .git)" ]; then
    echo "Repository already exists."
    exit 1
fi

git clone "$INITIAL_GIT_REPO"

# Clean out distracting files we no longer need. 
#RUN rm -rf .devcontainer .github .lib requirements.txt LICENSE  && \
#    mv lessons/* . && \
#    rm -rf lessons && \
#    git add -A && \
#    git commit -m "codeserver init"
