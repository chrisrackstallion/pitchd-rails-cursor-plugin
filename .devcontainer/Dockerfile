# Dev tooling only — project is bind-mounted at workspaceFolder (see devcontainer.json).
# Debian/glibc: supported base for Cursor and VS Code remote server (Alpine/musl is not).
#
# Ruby, not Node: this repo is a gem. Its own tooling is bundler, rspec, and
# rubocop; the payload under rails-agent-harness/ is markdown. Matches
# required_ruby_version in rails-agent-harness.gemspec.
FROM ruby:3.4-bookworm

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

# Gemfile.lock is committed and written by Bundler 4; the image ships 2.x, which
# refuses a lockfile from a newer major. Install the current bundler so
# postCreateCommand's `bundle install` matches the lockfile.
RUN gem install bundler --no-document

WORKDIR /workspaces
