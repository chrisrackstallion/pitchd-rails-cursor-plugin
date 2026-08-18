# frozen_string_literal: true

# Shared setup for the AgentHarnessRails cop specs.
#
# `rubocop/rspec/support` is already required by spec_helper when RuboCop is
# available; this adds the department itself and the shared context that makes
# `:config` build a cop from the `cop_config` each example declares.
require "rubocop/agent_harness_rails"

RSpec.configure do |config|
  config.include_context "config", :config
end
