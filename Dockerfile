FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

ENV VNC_RESOLUTION=600x600x16
ENV PASSWORD=code4life


# Local install of the VNC / NoVNC server
# COPY install.sh /tmp/install-vnc.sh
# installs /usr/local/share/desktop-init.sh
# RUN chmod 775 /tmp/install-vnc.sh 
# RUN /tmp/install-vnc.sh

RUN apt-get update && apt-get install -y --no-install-recommends \
    x11-apps \
    git \
    imagemagick && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/pip-tmp/
RUN pip3 install --upgrade pip
RUN pip3 --disable-pip-version-check --no-cache-dir install -r /tmp/pip-tmp/requirements.txt \
    && rm -rf /tmp/pip-tmp


EXPOSE 8080

# Clone the curriculum into the workspace
RUN mkdir /workspace
RUN git clone https://github.com/league-curriculum/Python-Apprentice /workspace

RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install extensions
COPY install-extensions.sh /tmp/install-extensions.sh
RUN chmod 775 /tmp/install-extensions.sh
RUN /tmp/install-extensions.sh

USER vscode

RUN git config --global pull.rebase true


CMD ["code-server",  "--disable-workspace-trust",  "--bind-addr", "0.0.0.0:8080", "/workspace"]
