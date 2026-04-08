# Dev tooling only — project is bind-mounted at workspaceFolder (see devcontainer.json).
FROM node:22-alpine

# bash: Cursor/VS Code server install scripts. zsh + shadow: Oh My Zsh and chsh.
RUN apk add --no-cache bash git openssh-client ca-certificates zsh curl shadow \
  && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
  && chsh -s /bin/zsh root

ENV SHELL=/bin/zsh

WORKDIR /workspaces
