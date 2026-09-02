# frozen_string_literal: true

require "rubocop"
require "pathname"

module RuboCop
  # Custom cops for rules in agent_harness_rails/rules/*.mdc that no existing cop
  # covers. Loaded only when an app opts in by inheriting rubocop-harness.yml —
  # nothing here is required by the gem's own library, so installing
  # agent_harness_rails does not put RuboCop in anyone's load path.
  module AgentHarnessRails
    PROJECT_ROOT = Pathname.new(__dir__).parent.parent.expand_path.freeze
    CONFIG_DEFAULT = PROJECT_ROOT.join("config", "default.yml").freeze
  end
end

# Takes the config file itself; passing a project root has not been supported
# since RuboCop 1.76.
RuboCop::ConfigLoader.inject_defaults!(RuboCop::AgentHarnessRails::CONFIG_DEFAULT)

# Shared mixins first; the cops are loaded in name order and several include
# these.
require_relative "agent_harness_rails/public_methods"
require_relative "agent_harness_rails/index_help"

# Which paths each cop applies to is config, not code: every cop's Include lives
# in config/default.yml, so an app can widen or narrow it without a patch.
Dir[File.join(__dir__, "cop", "agent_harness_rails", "*.rb")].sort.each { |cop| require cop }
