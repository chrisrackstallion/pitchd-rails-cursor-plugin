# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "json"

require_relative "../lib/rails_agent_harness"
require_relative "../lib/rails_agent_harness/installer"
require_relative "../lib/rails_agent_harness/cli"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random

  # Every example gets an empty project directory to install into.
  config.around do |example|
    Dir.mktmpdir("harness-spec") do |dir|
      @project = dir
      example.run
    end
  end
end

module ProjectHelpers
  def project
    @project
  end

  def payload_path(*parts)
    File.join(project, RailsAgentHarness::PAYLOAD_DIR, *parts)
  end

  def install(mode: :link)
    RailsAgentHarness::Installer.new(project_root: project, mode: mode).install
  end

  def check
    RailsAgentHarness::Installer.new(project_root: project).check
  end

  def manifest
    JSON.parse(File.read(payload_path(RailsAgentHarness::Manifest::FILENAME)))
        .fetch(RailsAgentHarness::Manifest::INSTALLER_KEY)
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

RSpec.configure { |config| config.include ProjectHelpers }
