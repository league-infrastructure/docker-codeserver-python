FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

ENV PASSWORD=code4life \
WORKSPACE_FOLDER=/workspace/Python-Apprentice \
DISPLAY_WIDTH=600 \
DISPLAY_HEIGHT=600

RUN curl -fsSL https://code-server.dev/install.sh | sh

RUN apt-get update && apt-get install -y --no-install-recommends \
    x11-apps \
    git \
    bash \
    net-tools \
    supervisor \
    oneko \
    imagemagick && \
    rm -rf /var/lib/apt/lists/*

COPY ./app /app

RUN pip3 install --upgrade pip
RUN pip3 --disable-pip-version-check --no-cache-dir install -r /app/requirements.txt 

EXPOSE 8080

RUN mkdir /app/run
RUN chown -R vscode /app/run

RUN mkdir /workspace
WORKDIR /workspace

RUN chown -R vscode /workspace

USER vscode

WORKDIR /app/run

RUN /app/setup.sh

# Install VSCode extensions
RUN code-server --install-extension "ms-python.python"
RUN code-server --install-extension "ms-python.autopep8"
RUN code-server --install-extension "ms-python.debugpy"
RUN code-server --install-extension "ms-python.isort"
RUN code-server --install-extension "ms-toolsai.jupyter"
RUN code-server --install-extension /app/vsc/jtl-vscode-0.2.1.vsix

# To keep git from complaining 
RUN git config --global pull.rebase true
RUN git config --global user.email "student@jointheleague.org"
RUN git config --global user.name "League Student"

RUN cd /workspace && git clone https://github.com/league-curriculum/Python-Apprentice
WORKDIR /workspace/Python-Apprentice
# Clean out distracting files we no longer need. 
RUN rm -rf .devcontainer
RUN rm -rf .github
RUN rm -rf .lib
RUN rm -rf requirements.txt
RUN rm -rf LICENSE
RUN mv lessons/* .
RUN rm -rf lessons
RUN git add -A
RUN git commit -m "codeserver init"

WORKDIR /workspace

ENTRYPOINT ["/app/entrypoint.sh"]

CMD ["code-server", "--config", "/app/code-server.yaml", "/workspace/Python-Apprentice"]

