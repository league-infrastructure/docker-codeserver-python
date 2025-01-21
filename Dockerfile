FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

ENV PASSWORD=code4life \
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
RUN chown -R vscode /workspace

USER vscode

WORKDIR /app/run

RUN /app/setup.sh
RUN /app/install-extensions.sh

RUN git config --global pull.rebase true
RUN git config --global user.email "student@jointheleague.org"
RUN git config --global user.name "League Student"


ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/command.sh"]