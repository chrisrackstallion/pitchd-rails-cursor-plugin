# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "json"
require "yaml"
require "rubocop"
require "rubocop/rspec/support"

# The root file loads the whole library; the CLI is separate, as in exe/.
require_relative "../lib/agent_harness_rails"
require_relative "../lib/agent_harness_rails/cli"

module ProjectHelpers
  def project
    @project
  end

  def payload_path(*parts)
    File.join(project, AgentHarnessRails::PAYLOAD_DIR, *parts)
  end

  def install(mode: :link)
    AgentHarnessRails::Installer.new(project_root: project, mode: mode).install
  end

  def check
    AgentHarnessRails::Installer.new(project_root: project).check
  end

  def manifest
    JSON.parse(File.read(payload_path(AgentHarnessRails::Manifest::FILENAME)))
        .fetch(AgentHarnessRails::Manifest::INSTALLER_KEY)
  end

  # A file the gem genuinely ships, used as the subject of ownership tests.
  def owned_relative_path
    "rules/models.mdc"
  end

  def write_app_file(relative, body)
    path = payload_path(relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    path
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  config.include ProjectHelpers

  # Every example gets an empty project directory to install into.
  config.around do |example|
    Dir.mktmpdir("harness-spec") do |dir|
      @project = dir
      example.run
    end
  end
end
