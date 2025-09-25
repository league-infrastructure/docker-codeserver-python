FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

LABEL org.opencontainers.image.description="Code-server container for the Python Apprentice curriculum, with a VNC server and a web-based IDE"
LABEL org.opencontainers.image.source="https://github.com/league-infrastructure/docker-codeserver-python.git"

ENV LEAGUE_CODESERVER=1 \
    PASSWORD=code4life \
    WORKSPACE_FOLDER=/workspace/ \
    HOME=/home/vscode \
    DISPLAY_WIDTH=600 \
    DISPLAY_HEIGHT=600 \
    DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:0.0 \
    KST_REPORT_INTERVAL=10 \
    KST_DEBUG=0

RUN curl -fsSL https://code-server.dev/install.sh | sh

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    bash \
    net-tools  netcat-traditional nmap \
    supervisor \
    build-essential \
    cron \
    tzdata \
    procps \
    tini \
    tigervnc-standalone-server tigervnc-tools \
    dbus \
    x11vnc xvfb  x11-xserver-utils fluxbox novnc \
    imagemagick \
    oneko  x11-apps \
    gh \
    && rm -rf /var/lib/apt/lists/*


# Install desktop-lite, thich will duplicate some of the apt-get installs.
# RUN curl https://raw.githubusercontent.com/devcontainers/features/refs/heads/main/src/desktop-lite/install.sh | bash 

# Install rclone
RUN curl -fsSL https://rclone.org/install.sh | bash

ENV TZ=America/Los_Angeles

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY ./app /app



# Copy the crontab file into the appropriate location
RUN mv /app/crontab /etc/crontab
RUN crontab /etc/crontab

RUN pip3 install --upgrade pip
RUN pip3 --disable-pip-version-check --no-cache-dir install -r /app/requirements.txt 

# Make novnc run from the index.html

# Disable VNC password requirement
RUN mkdir -p /root/.vnc && echo "" > /root/.vnc/passwd && chmod 600 /root/.vnc/passwd

# Also set up .vnc/passwd for vscode user
RUN mkdir -p /home/vscode/.vnc && echo "" > /home/vscode/.vnc/passwd && chmod 600 /home/vscode/.vnc/passwd && chown -R vscode:vscode /home/vscode/.vnc

EXPOSE 8080
EXPOSE 80 
EXPOSE 6080

RUN mkdir /app/run
RUN chown -R vscode /app/run

RUN mkdir /workspace
RUN chown -R vscode /workspace
RUN chown -R vscode /app/extensions
RUN mkdir -p /home/vscode/.cache && chown -R vscode /home/vscode/.cache

USER vscode

RUN code-server --extensions-dir /app/extensions \
--install-extension /app/extensions/jtl-syllabus-1.20250618.1.vsix \
--install-extension "ms-python.python"  

# --install-extension "ms-python.autopep8" \
# --install-extension "ms-python.debugpy" \
# --install-extension "ms-python.isort" \
# --install-extension "ms-toolsai.jupyter" \

WORKDIR /app/run


# To keep git from complaining 
RUN git config --global pull.rebase true && \
    git config --global user.email "student@jointheleague.org" && \
    git config --global user.name "League Student"


# Newline after the long PS1
RUN echo 'export PS1="${PS1}\n$ "' >> ~/.bashrc


WORKDIR /workspace
USER root

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/usr/bin/supervisord", "-c", "/app/supervisord.conf"]
