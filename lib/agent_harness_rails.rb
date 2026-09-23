# frozen_string_literal: true

require_relative "agent_harness_rails/version"

# Rails conventions for coding agents — skills, rules, and agent definitions
# vendored into an application so Cursor and Claude Code can both read them from
# the project directory alone.
#
# The gem is an install/update tool, not a runtime dependency: nothing in a
# consuming app ever loads harness content through Ruby. `install` vendors the
# payload and links the editor directories at it; after that the files are read
# by the agent, from the app.
#
# One flat constant matching the gem name — deliberately nothing under `Rails::`,
# which would reopen the Rails constant inside a Rails application.
module AgentHarnessRails
  # Directory name used both inside this gem and inside a consuming app, so one
  # path string (`agent_harness_rails/rules/models.mdc`) is correct in both.
  PAYLOAD_DIR = "agent_harness_rails"

  # Subdirectories of the payload, in the order a reader meets them.
  PAYLOAD_SUBDIRS = %w[skills rules agents].freeze

  # Payload-relative paths that develop this repo rather than a consuming app.
  # They sit in the payload so this repo's own editor links pick them up, and are
  # dropped from both `install` and the gem — a consuming app has no use for a
  # skill about editing the harness it consumes. The gemspec repeats the list
  # literally rather than loading this library; spec/gem_spec.rb asserts they agree.
  DEV_ONLY = %w[skills/maintaining-harness].freeze

  class Error < StandardError; end

  class << self
    # Absolute path to the installed gem.
    def root
      File.expand_path("..", __dir__)
    end

    # Absolute path to the payload this gem ships.
    def payload
      File.join(root, PAYLOAD_DIR)
    end

    # True for a payload-relative path that exists only to develop this repo.
    def dev_only?(relative)
      DEV_ONLY.any? { |path| relative == path || relative.start_with?("#{path}/") }
    end
  end
end

# The whole library, so `require "agent_harness_rails"` yields a working
# Installer. The CLI is left to exe/ — it exists for the executable, not callers.
require_relative "agent_harness_rails/installer"
