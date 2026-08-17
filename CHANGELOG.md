# Changelog

All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Initial version, in local use while the harness proves itself.

### Added

- `install` vendors the skills, rules, and agent definitions into
  `rails-agent-harness/` and links `.claude/` and `.cursor/` at it, migrating any
  content the app already had in those directories so nothing is shadowed or lost.
- `check` verifies the vendored harness against the gem for use in CI, reporting
  local overrides without failing and drift with a non-zero exit.
- `update` re-vendors after a gem bump, keeping local edits and pruning files the
  gem no longer ships.
- Ships `rubocop.yml` for consuming apps to `inherit_gem` as a thin layer over
  rubocop-rails-omakase.
