# Dev tooling only — project is bind-mounted at workspaceFolder (see devcontainer.json).
# Debian/glibc: supported base for Cursor and VS Code remote server (Alpine/musl is not).
FROM node:22-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    ca-certificates \
    zsh \
    curl \
  && rm -rf /var/lib/apt/lists/* \
  && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
  && chsh -s /usr/bin/zsh root

ENV SHELL=/usr/bin/zsh

WORKDIR /workspaces
