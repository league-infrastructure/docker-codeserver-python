FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

ENV PASSWORD=code4life \
    WORKSPACE_FOLDER=/workspace/Python-Apprentice \
    DISPLAY_WIDTH=600 \
    DISPLAY_HEIGHT=600 \
    DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    HOME=/workspace \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:0.0 \
    KST_REPORT_RATE=30 \
    KST_DEBUG=0

RUN curl -fsSL https://code-server.dev/install.sh | sh

RUN apt-get update && apt-get install -y --no-install-recommends \
    x11-apps \
    git \
    bash \
    net-tools  netcat-traditional nmap \
    supervisor \
    oneko \
    build-essential \
    cron \
    tzdata \
    procps \
    tini \
    fluxbox \
    novnc \
    x11vnc \
    xvfb \
    imagemagick && \
    rm -rf /var/lib/apt/lists/*

ENV TZ=America/Los_Angeles

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


COPY ./app /app

# Copy the crontab file into the appropriate location
RUN mv /app/crontab /etc/crontab
RUN crontab /etc/crontab

RUN pip3 install --upgrade pip
RUN pip3 --disable-pip-version-check --no-cache-dir install -r /app/requirements.txt 

# Make novnc run from the index.html
RUN cp /usr/share/novnc/vnc_lite.html  /usr/share/novnc/index.html

EXPOSE 8080
EXPOSE 6080

RUN mkdir /app/run
RUN chown -R vscode /app/run


WORKDIR /workspace

RUN chown -R vscode /workspace

USER vscode

WORKDIR /app/run

RUN /app/setup.sh

# Install VSCode extensions
RUN code-server --install-extension "ms-python.python" \
    --install-extension "ms-python.autopep8" \
    --install-extension "ms-python.debugpy" \
    --install-extension "ms-python.isort" \
    --install-extension "ms-toolsai.jupyter" \
    --install-extension /app/vsc/jtl-vscode-0.2.1.vsix

# To keep git from complaining 
RUN git config --global pull.rebase true && \
    git config --global user.email "student@jointheleague.org" && \
    git config --global user.name "League Student"

RUN cd /workspace && git clone https://github.com/league-curriculum/Python-Apprentice
WORKDIR /workspace/Python-Apprentice

# Clean out distracting files we no longer need. 
RUN rm -rf .devcontainer .github .lib requirements.txt LICENSE  && \
    mv lessons/* . && \
    rm -rf lessons && \
    git add -A && \
    git commit -m "codeserver init"

WORKDIR /workspace
USER root

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/usr/bin/supervisord", "-c", "/app/supervisord.conf"]
