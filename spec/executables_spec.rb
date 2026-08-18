# frozen_string_literal: true

require "spec_helper"
require "open3"

# The other specs drive the libraries in-process. These drive the `exe/` shims as
# real subprocesses, because that is the only thing in-process specs cannot cover:
# a shim requiring a path that does not exist, or an executable bit that never got
# set, fails identically to a working one until someone actually runs it.
#
# Deliberately thin. Behaviour — which findings, which messages, which exit code
# for which tree — belongs in spec/evals_spec.rb, where each example builds the
# tree it needs and says what it expects.
RSpec.describe "executables" do
  ROOT = File.expand_path("..", __dir__)
  FIXTURE_APP = File.join(ROOT, "fixtures/primitives_app")

  def run(*argv)
    Open3.capture2e({ "RUBYOPT" => nil }, RbConfig.ruby, "-I#{File.join(ROOT, 'lib')}", *argv, chdir: ROOT)
  end

  describe "exe/rails-evals" do
    it "is executable" do
      expect(File).to be_executable(File.join(ROOT, "exe/rails-evals"))
    end

    it "runs green against the fixture app" do
      output, status = run("exe/rails-evals", "--path", FIXTURE_APP)

      expect(status).to be_success, output
      expect(output).to include("1 capability inspected", "4 clauses", "no offences")
    end

    it "reports a tree it cannot find rather than crashing" do
      output, status = run("exe/rails-evals", "--path", ROOT)

      expect(status).not_to be_success
      expect(output).to start_with("error: no capability docs")
    end
  end

  describe "exe/agent_harness_rails" do
    it "is executable" do
      expect(File).to be_executable(File.join(ROOT, "exe/agent_harness_rails"))
    end

    it "loads and reports its version" do
      output, status = run("exe/agent_harness_rails", "version")

      expect(status).to be_success, output
      expect(output.strip).to eq(AgentHarnessRails::VERSION)
    end
  end
end
