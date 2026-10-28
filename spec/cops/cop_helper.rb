# frozen_string_literal: true

# Shared setup for the AgentHarnessRails cop specs.
#
# `rubocop/rspec/support` is already required by spec_helper when RuboCop is
# available; this adds the department itself and the shared context that makes
# `:config` build a cop from the `cop_config` each example declares.
require "rubocop/agent_harness_rails"
require "rubydex"

module IndexProjectHelpers
  # Writes `files` (relative path => source) into the example's project
  # directory, indexes them with Rubydex, hands the graph to the cop the way
  # RuboCop's runner does, and returns the absolute path of `subject` to pass to
  # `expect_offense`. The subject's source may carry offense annotations; they
  # are stripped before the file is written.
  def index_project(files, subject:)
    paths = files.map do |relative, source|
      path = File.join(project, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, RuboCop::RSpec::ExpectOffense::AnnotatedSource.parse(source).plain_source)
      path
    end

    graph = Rubydex::Graph.new
    graph.index_all(paths)
    graph.resolve
    cop.project_index = graph

    File.join(project, subject)
  end
end

RSpec.configure do |config|
  config.include_context "config", :config
  config.include IndexProjectHelpers
end
