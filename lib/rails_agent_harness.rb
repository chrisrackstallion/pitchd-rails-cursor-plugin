# frozen_string_literal: true

require_relative "rails_agent_harness/version"

# Rails conventions for coding agents — skills, rules, and agent definitions
# vendored into an application so Cursor and Claude Code can both read them from
# the project directory alone.
#
# The gem is an install/update tool, not a runtime dependency: nothing in a
# consuming app ever loads harness content through Ruby. `install` vendors the
# payload and links the editor directories at it; after that the files are read
# by the agent, from the app.
#
# Deliberately NOT namespaced as Rails::Agent::Harness — that would reopen the
# `Rails` constant inside a Rails application.
module RailsAgentHarness
  # Directory name used both inside this gem and inside a consuming app, so one
  # path string (`rails-agent-harness/rules/models.mdc`) is correct in both.
  PAYLOAD_DIR = "rails-agent-harness"

  # Subdirectories of the payload, in the order a reader meets them.
  PAYLOAD_SUBDIRS = %w[skills rules agents].freeze

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
  end
end
